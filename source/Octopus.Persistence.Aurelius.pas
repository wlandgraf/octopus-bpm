unit Octopus.Persistence.Aurelius;

interface

uses
  System.SysUtils,
  System.Rtti,
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Explorer,
  Octopus.Persistence.Common,
  Octopus.Entities,
  Octopus.Process;

type
  TAureliusInstanceData = class(TInterfacedObject, IProcessInstanceData)
  private
    FManager: TObjectManager;
    FInstance: TProcessInstanceEntity;
    FInstanceId: string;
    FActiveTokens: TDictionary<TToken, TTokenEntity>;
    procedure LoadActiveTokens;
    procedure SaveToken(Token: TToken);
    procedure SaveVariable(InstanceVar: TVariableEntity; Value: TValue);
    function TokenFromEntity(InstanceToken: TTokenEntity): TToken;
    function VariableValue(InstanceVar: TVariableEntity): TValue;
  public
    constructor Create(Connection: IDBConnection; const InstanceId: string);
    destructor Destroy; override;
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition); overload;
    function CountTokens: integer;
    function GetTokens: TArray<TToken>; overload;
    function GetTokens(Node: TFlowNode): TArray<TToken>; overload;
    procedure RemoveToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; const Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
  end;

  TAureliusPersistence = class(TInterfacedObject)
  strict private
    FPool: IDBConnectionPool;
  protected
    function CreateManager: TObjectManager;
    property Pool: IDBConnectionPool read FPool;
  public
    constructor Create(APool: IDBConnectionPool);
  end;

  TAureliusRepository = class(TAureliusPersistence, IOctopusRepository)
  public
    function PublishDefinition(const Name: string; Process: TWorkflowProcess): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
  end;

  TAureliusRuntime = class(TAureliusPersistence, IOctopusRuntime)
  public
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

uses
  Aurelius.Criteria.Base,
  Aurelius.Criteria.Linq,
  Aurelius.Criteria.Projections,
  Octopus.DataTypes,
  Octopus.Exceptions,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer;

{ TProcessInstance }

procedure TAureliusInstanceData.AddToken(Transition: TTransition);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Transition := Transition;
  SaveToken(token);
end;

procedure TAureliusInstanceData.AddToken(Node: TFlowNode);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Node := Node;
  SaveToken(token);
end;

function TAureliusInstanceData.CountTokens: integer;
begin
  result := FActiveTokens.Count;
end;

constructor TAureliusInstanceData.Create(Connection: IDBConnection; const InstanceId: string);
begin
  FManager := TObjectManager.Create(Connection, TMappingExplorer.Get(OctopusModel));
  FActiveTokens := TDictionary<TToken,TTokenEntity>.Create;
  FInstanceId := InstanceId;
  FInstance := FManager.Find<TProcessInstanceEntity>(InstanceId);
  LoadActiveTokens;
end;

destructor TAureliusInstanceData.Destroy;
begin
  FManager.Free;
  FActiveTokens.Free;
  inherited;
end;

function TAureliusInstanceData.GetLocalVariable(Token: TToken; const Name: string): TValue;
var
  tokenEnt: TTokenEntity;
  varEnt: TVariableEntity;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    varEnt := FManager.Find<TVariableEntity>
      .Where((Linq['Instance'] = FInstance.Id)
         and (Linq['Token'] = tokenEnt.Id)
         and (Linq['Name'] = Name))
      .UniqueResult;

    if varEnt <> nil then
      exit(VariableValue(varEnt));
  end;
  result := TValue.Empty;
end;

function TAureliusInstanceData.GetTokens: TArray<TToken>;
begin
  result := FActiveTokens.Keys.ToArray;
end;

function TAureliusInstanceData.GetTokens(Node: TFlowNode): TArray<TToken>;
var
  token: TToken;
begin
  SetLength(result, 0);
  for token in FActiveTokens.Keys do
    if token.Node = Node then
    begin
      SetLength(result, Length(result) + 1);
      result[Length(result) - 1] := token;
    end;
end;

function TAureliusInstanceData.GetVariable(const Name: string): TValue;
var
  varEnt: TVariableEntity;
begin
  varEnt := FManager.Find<TVariableEntity>
    .Where((Linq['Instance'] = FInstance.Id)
       and (Linq['Token'].IsNull)
       and (Linq['Name'] = Name))
    .UniqueResult;

  if varEnt <> nil then
    result := VariableValue(varEnt)
  else
    result := TValue.Empty;
end;

function TAureliusInstanceData.LastToken(Node: TFlowNode): TToken;
var
  tokenList: TList<TTokenEntity>;
begin
  tokenList := FManager.Find<TTokenEntity>
    .Where((Linq['Instance'] = FInstance.Id)
        and Linq['FinishedOn'].IsNotNull)
    .OrderBy('FinishedOn', false)
    .Take(1)
    .List;

  if tokenList.Count > 0 then
    result := TokenFromEntity(tokenList[0])
  else
    result := nil;
end;

procedure TAureliusInstanceData.LoadActiveTokens;
var
  tokenList: TList<TTokenEntity>;
  tokenEnt: TTokenEntity;
begin
  FActiveTokens.Clear;

  tokenList := FManager.Find<TTokenEntity>
    .Where((Linq['Instance'] = FInstance.Id)
        and Linq['FinishedOn'].IsNull)
    .List;

  for tokenEnt in tokenList do
    FActiveTokens.Add(TokenFromEntity(tokenEnt), tokenEnt);
end;

procedure TAureliusInstanceData.RemoveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    tokenEnt.FinishedOn := Now; // TODO
    FManager.Flush;
    FActiveTokens.Remove(Token);
  end;
end;

procedure TAureliusInstanceData.SaveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
begin
  tokenEnt := TTokenEntity.Create;
  tokenEnt.CreatedOn := Now; // TODO
  if Token.Transition <> nil then
    tokenEnt.TransitionId := Token.Transition.Id;
  tokenEnt.NodeId := Token.Node.Id;
  FManager.Save(tokenEnt);
end;

procedure TAureliusInstanceData.SaveVariable(InstanceVar: TVariableEntity; Value: TValue);
var
  dataType: TOctopusDataType;
begin
  dataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);

  InstanceVar.Value := TWorkflowSerializer.ValueToJson(Value, dataType.NativeType);
  InstanceVar.ValueType := dataType.Name;

  FManager.SaveOrUpdate(InstanceVar);
end;

procedure TAureliusInstanceData.SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
var
  tokenEnt: TTokenEntity;
  varEnt: TVariableEntity;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    varEnt := FManager.Find<TVariableEntity>
      .Where((Linq['Instance'] = FInstance.Id)
         and (Linq['Token'] = tokenEnt.Id)
         and (Linq['Name'] = Name))
      .UniqueResult;

    if varEnt = nil then
    begin
      varEnt := TVariableEntity.Create;
      varEnt.Instance := FInstance;
      varEnt.Token := tokenEnt;
      varEnt.Name := Name;
    end;

    SaveVariable(varEnt, Value);
  end;
end;

procedure TAureliusInstanceData.SetVariable(const Name: string; const Value: TValue);
var
  varEnt: TVariableEntity;
begin
  varEnt := FManager.Find<TVariableEntity>
    .Where((Linq['Instance'] = FInstance.Id)
       and (Linq['Token'].IsNull)
       and (Linq['Name'] = Name))
    .UniqueResult;

  if varEnt = nil then
  begin
    varEnt := TVariableEntity.Create;
    varEnt.Instance := FInstance;
    varEnt.Name := Name;
  end;

  SaveVariable(varEnt, Value);
end;

function TAureliusInstanceData.TokenFromEntity(InstanceToken: TTokenEntity): TToken;
begin
  result := TToken.Create;
//  if not InstanceToken.TransitionId.IsNull then
//    result.Transition := FProcess.GetTransition(InstanceToken.TransitionId)
//  else
//    result.Node := FProcess.GetNode(InstanceToken.NodeId);
end;

function TAureliusInstanceData.VariableValue(InstanceVar: TVariableEntity): TValue;
begin
  if Trim(InstanceVar.Value) <> '' then
    result := TWorkflowDeserializer.ValueFromJson(InstanceVar.Value,
      TOctopusDataTypes.Default.Get(InstanceVar.ValueType).NativeType)
  else
    result := TValue.Empty;
end;

{ TAureliusPersistence }

constructor TAureliusPersistence.Create(APool: IDBConnectionPool);
begin
  inherited Create;
  FPool := APool;
end;

function TAureliusPersistence.CreateManager: TObjectManager;
begin
  Result := TObjectManager.Create(Pool.GetConnection, TMappingExplorer.Get(OctopusModel));
end;

{ TAureliusRuntime }

function TAureliusRuntime.CreateInstance(
  const ProcessId: string): IProcessInstanceData;
var
  Manager: TObjectManager;
  Instance: TProcessInstanceEntity;
  Definition: TProcessDefinitionEntity;
begin
  Manager := CreateManager;
  try
    Definition := Manager.Find<TProcessDefinitionEntity>(ProcessId);
//    if Definition = nil then
//      raise EOctopusDefinitionNotFound.Create(ProcessId);

    Instance := TProcessInstanceEntity.Create;
    Manager.AddToGarbage(Instance);
    Instance.CreatedOn := Now;
    Instance.ProcessDefinition := Definition;
    Manager.Save(Instance);

    Result := TAureliusInstanceData.Create(Pool.GetConnection, Instance.Id);
  finally
    Manager.Free;
  end;
end;

{ TAureliusRepository }

function TAureliusRepository.GetDefinition(
  const ProcessId: string): TWorkflowProcess;
begin
end;

function TAureliusRepository.PublishDefinition(const Name: string;
  Process: TWorkflowProcess): string;
var
  Manager: TObjectManager;
  VersionResult: TCriteriaResult;
  NextVersion: Integer;
  Definition: TProcessDefinitionEntity;
begin
  Manager := CreateManager;
  try
    VersionResult := Manager.Find<TProcessDefinitionEntity>
      .Select(Linq['Version'].Max)
      .Where(Linq['Name'].ILike(Name))
      .UniqueValue;
    try
      NextVersion := VersionResult.Values[0] + 1;
    finally
      VersionResult.Free;
    end;

    Definition := TProcessDefinitionEntity.Create;
    Manager.AddToGarbage(Definition);
    Definition.Name := Name;
    Definition.Version := NextVersion;
    Definition.Status := TProcessDefinitionStatus.Published;
    Definition.CreatedOn := Now;
    Definition.Process.AsUnicodeString :=  TWorkflowSerializer.ProcessToJson(Process);
    Manager.Save(Definition);
    Result := Definition.Id;
  finally
    Manager.Free;
  end;
end;

end.
