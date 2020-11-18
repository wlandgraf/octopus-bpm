unit Octopus.Persistence.Aurelius;

{$I Octopus.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Explorer,
  Octopus.Persistence.Common,
  Octopus.Entities,
  Octopus.Process;

type
  TAureliusPersistence = class(TInterfacedObject)
  strict private
    FPool: IDBConnectionPool;
  protected
    function CreateManager: TObjectManager;
    property Pool: IDBConnectionPool read FPool;
  public
    constructor Create(APool: IDBConnectionPool);
  end;

  TAureliusInstanceData = class(TAureliusPersistence, IProcessInstanceData)
  private
    FInstanceId: string;
    Manager: TObjectManager;
    procedure SaveToken(Token: TToken);
    procedure FillVariable(InstanceVar: TVariableEntity; Value: TValue);
    function TokenFromEntity(InstanceToken: TTokenEntity): TToken;
    function VariableValue(InstanceVar: TVariableEntity): TValue;
    function GetInstanceEntity(Manager: TObjectManager): TProcessInstanceEntity;
  public
    constructor Create(Pool: IDBConnectionPool; const InstanceId: string);
    destructor Destroy; override;
  public
    { IProcessInstanceData methods }
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition); overload;
    function GetTokens: TArray<TToken>; overload;
    function GetTokens(Node: TFlowNode): TArray<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; const Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
  end;

  TProcessFromIdProc = reference to procedure(const ProcessId: string;
    var Process: TWorkflowProcess);
  TProcessFromNameProc = reference to procedure(const ProcessName: string;
    Version: Integer; var Process: TWorkflowProcess);

  TAureliusRepository = class(TAureliusPersistence, IOctopusRepository)
  strict private
    FOnGetProcessFromName: TProcessFromNameProc;
    FOnGetProcessFromId: TProcessFromIdProc;
  public
    function PublishDefinition(const Name: string; Process: TWorkflowProcess): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
    property OnGetProcessFromId: TProcessFromIdProc read FOnGetProcessFromId write FOnGetProcessFromId;
    property OnGetProcessFromName: TProcessFromNameProc read FOnGetProcessFromName write FOnGetProcessFromName;
  end;

  TAureliusRuntime = class(TAureliusPersistence, IOctopusRuntime)
  public
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

uses
  System.Variants,
  Aurelius.Criteria.Base,
  Aurelius.Criteria.Linq,
  Aurelius.Criteria.Projections,
  Aurelius.Types.Nullable,
  Octopus.DataTypes,
  Octopus.Exceptions,
  Octopus.Resources,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer;

{ TProcessInstance }

procedure TAureliusInstanceData.ActivateToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    tokenEnt := Manager.Find<TTokenEntity>(Token.Id);
    if tokenEnt = nil then
      raise EOctopusTokenNotFound.CreateFmt(SErrorActivateTokenNotFound, [Token.Id]);

    case tokenEnt.Status of
      TTokenEntityStatus.Active:
        Exit;
      TTokenEntityStatus.Waiting:
        begin
          tokenEnt.Status := TTokenEntityStatus.Active;
          Manager.Flush(tokenEnt);
        end;
    else
      raise EOctopusException.CreateFmt(SErrorActivateTokenWrongStatus,
        [Token.Id, Ord(tokenEnt.Status)]);
    end;
  finally
    Manager.Free;
  end;
end;

procedure TAureliusInstanceData.AddToken(Transition: TTransition);
var
  token: TToken;
begin
  token := TToken.Create;
  try
    token.TransitionId := Transition.Id;
    Assert(Transition.Target <> nil);
    token.NodeId := Transition.Target.Id;
  //  token.ProducerId := ProducerId;
    SaveToken(token);
  finally
    token.Free;
  end;
end;

procedure TAureliusInstanceData.AddToken(Node: TFlowNode);
var
  token: TToken;
begin
  token := TToken.Create;
  try
    token.NodeId := Node.Id;
  //  token.ProducerId := ProducerId;
    SaveToken(token);
  finally
    token.Free;
  end;
end;

constructor TAureliusInstanceData.Create(Pool: IDBConnectionPool; const InstanceId: string);
begin
  inherited Create(Pool);
  FInstanceId := InstanceId;
end;

procedure TAureliusInstanceData.DeactivateToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    tokenEnt := Manager.Find<TTokenEntity>(Token.Id);
    if tokenEnt = nil then
      raise EOctopusTokenNotFound.CreateFmt(SErrorDeactivateTokenNotFound, [Token.Id]);

    case tokenEnt.Status of
      TTokenEntityStatus.Active:
        begin
          tokenEnt.Status := TTokenEntityStatus.Waiting;
          Manager.Flush(tokenEnt);
        end;
      TTokenEntityStatus.Waiting:
        Exit;
    else
      raise EOctopusException.CreateFmt(SErrorDeactivateTokenWrongStatus,
        [Token.Id, Ord(tokenEnt.Status)]);
    end;
  finally
    Manager.Free;
  end;
end;

destructor TAureliusInstanceData.Destroy;
begin
  inherited;
end;

function TAureliusInstanceData.GetInstanceEntity(
  Manager: TObjectManager): TProcessInstanceEntity;
begin
  Result := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Result = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);
end;

function TAureliusInstanceData.GetLocalVariable(Token: TToken; const Name: string): TValue;
var
  varEnt: TVariableEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    varEnt := Manager.Find<TVariableEntity>
      .CreateAlias('Instance', 'i')
      .CreateAlias('Token', 't')
      .Where((Linq['i.Id'] = FInstanceId)
         and (Linq['t.Id'] = token.Id)
         and (Linq['Name'].ILike(Name)))
      .UniqueResult;

    if varEnt <> nil then
      Result := VariableValue(varEnt)
    else
      Result := TValue.Empty;
  finally
    Manager.Free;
  end;
end;

function TAureliusInstanceData.GetTokens: TArray<TToken>;
var
  tokenList: TList<TTokenEntity>;
  Manager: TObjectManager;
  I: Integer;
begin
  Manager := CreateManager;
  try
    // Most recent tokens first
    tokenList := Manager.Find<TTokenEntity>
      .CreateAlias('Instance', 'i')
      .Where(Linq['i.Id'] = FInstanceId)
      .OrderBy(Linq['CreatedOn'], False)
      .List;

    SetLength(Result, tokenList.Count);
    for I := 0 to tokenList.Count - 1 do
      Result[I] := TokenFromEntity(tokenList[I]);
  finally
    Manager.Free;
  end;
end;

function TAureliusInstanceData.GetTokens(Node: TFlowNode): TArray<TToken>;
var
  tokenList: TList<TTokenEntity>;
  Manager: TObjectManager;
  I: Integer;
begin
  Manager := CreateManager;
  try
    // Most recent tokens first
    tokenList := Manager.Find<TTokenEntity>
      .CreateAlias('Instance', 'i')
      .Where(Linq['i.Id'] = FInstanceId)
      .Where(Linq['NodeId'] = Node.Id)
      .OrderBy(Linq['CreatedOn'], False)
      .List;

    SetLength(Result, tokenList.Count);
    for I := 0 to tokenList.Count - 1 do
      Result[I] := TokenFromEntity(tokenList[I]);
  finally
    Manager.Free;
  end;
end;

function TAureliusInstanceData.GetVariable(const Name: string): TValue;
var
  varEnt: TVariableEntity;
begin
  Manager := CreateManager;
  try
    varEnt := Manager.Find<TVariableEntity>
      .CreateAlias('Instance', 'i')
      .CreateAlias('Token', 't')
      .Where((Linq['i.Id'] = FInstanceId)
         and (Linq['t.Id'].IsNull)
         and (Linq['Name'].ILike(Name)))
      .UniqueResult;

    if varEnt <> nil then
      Result := VariableValue(varEnt)
    else
      Result := TValue.Empty;
  finally
    Manager.Free;
  end;
end;

function TAureliusInstanceData.LastToken(Node: TFlowNode): TToken;
var
  tokenList: TList<TTokenEntity>;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    tokenList := Manager.Find<TTokenEntity>
      .CreateAlias('Instance', 'i')
      .Where(
        (Linq['i.Id'] = FInstanceId) and
        (Linq['NodeId'] = Node.Id)
      )
      .OrderBy('CreatedOn', false)
      .Take(1)
      .List;

    if tokenList.Count > 0 then
      result := TokenFromEntity(tokenList[0])
    else
      result := nil;
  finally
    Manager.Free;
  end;
end;

procedure TAureliusInstanceData.RemoveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    tokenEnt := Manager.Find<TTokenEntity>(Token.Id);
    if tokenEnt = nil then
      raise EOctopusTokenNotFound.CreateFmt(SErrorFinishTokenNotFound, [Token.Id]);

    if tokenEnt.Status = TTokenEntityStatus.Finished then

    tokenEnt.FinishedOn := Now;
    tokenEnt.Status := TTokenEntityStatus.Finished;
//    tokenEnt.ConsumerId := ConsumerId;
    Manager.Flush(tokenEnt);
  finally
    Manager.Free;
  end;
end;

procedure TAureliusInstanceData.SaveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    tokenEnt := TTokenEntity.Create;
    Manager.AddToGarbage(tokenEnt);
    tokenEnt.Status := TTokenEntityStatus.Active;
    tokenEnt.CreatedOn := Now;
    tokenEnt.TransitionId := Token.TransitionId;
    tokenEnt.NodeId := Token.NodeId;
    tokenEnt.Instance := GetInstanceEntity(Manager);
    Manager.Save(tokenEnt);
  finally
    Manager.Free;
  end;
end;

procedure TAureliusInstanceData.FillVariable(InstanceVar: TVariableEntity; Value: TValue);
var
  dataType: TOctopusDataType;
begin
  if Value.TypeInfo <> nil then
  begin
    dataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);
    InstanceVar.Value := TWorkflowSerializer.ValueToJson(Value, dataType.NativeType);
    InstanceVar.ValueType := dataType.Name;
  end
  else
  begin
    InstanceVar.Value := '';
    InstanceVar.ValueType := '';
  end;
end;

procedure TAureliusInstanceData.SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
var
  tokenEnt: TTokenEntity;
  varEnt: TVariableEntity;
begin
  Manager := CreateManager;
  try
    varEnt := Manager.Find<TVariableEntity>
      .CreateAlias('Instance', 'i')
      .CreateAlias('Token', 't')
      .Where((Linq['i.Id'] = FInstanceId)
         and (Linq['t.Id'] = token.Id)
         and (Linq['Name'].ILike(Name)))
      .UniqueResult;

    if varEnt = nil then
    begin
      tokenEnt := Manager.Find<TTokenEntity>(Token.Id);
      if tokenEnt = nil then
        raise EOctopusTokenNotFound.CreateFmt(SErrorSetVariableTokenNotFound, [Name, Token.Id]);

      varEnt := TVariableEntity.Create;
      Manager.AddToGarbage(varEnt);
      varEnt.Instance := GetInstanceEntity(Manager);
      varEnt.Token := tokenEnt;
      varEnt.Name := Name;
      FillVariable(varEnt, Value);
      Manager.Save(varEnt);
    end
    else
    begin
      FillVariable(varEnt, Value);
      Manager.Flush(varEnt);
    end;
  finally
    Manager.Free;
  end;
end;

procedure TAureliusInstanceData.SetVariable(const Name: string; const Value: TValue);
var
  varEnt: TVariableEntity;
  Manager: TObjectManager;
begin
  Manager := CreateManager;
  try
    varEnt := Manager.Find<TVariableEntity>
      .CreateAlias('Instance', 'i')
      .CreateAlias('Token', 't')
      .Where((Linq['i.Id'] = FInstanceId)
         and (Linq['t.Id'].IsNull)
         and (Linq['Name'].ILike(Name)))
      .UniqueResult;

    if varEnt = nil then
    begin
      varEnt := TVariableEntity.Create;
      Manager.AddToGarbage(varEnt);
      varEnt.Instance := GetInstanceEntity(Manager);
      varEnt.Name := Name;
      FillVariable(varEnt, Value);
      Manager.Save(varEnt);
    end
    else
    begin
      FillVariable(varEnt, Value);
      Manager.Flush(varEnt);
    end;
  finally
    Manager.Free;
  end;
end;

function TAureliusInstanceData.TokenFromEntity(InstanceToken: TTokenEntity): TToken;
const
  TokenStatusMap: array[TTokenEntityStatus] of TTokenStatus =
    (TTokenStatus.Active, TTokenSTatus.Waiting, TTokenStatus.Finished);
begin
  Result := TToken.Create;
  Result.Id := InstanceToken.Id;
  Result.TransitionId := InstanceToken.TransitionId.ValueOrDefault;
  Result.NodeId := InstanceToken.NodeId.ValueOrDefault;
  Result.ConsumerId := InstanceToken.ConsumerId.ValueOrDefault;
  Result.ProducerId := InstanceToken.ProducerId.ValueOrDefault;
  Result.Status := TokenStatusMap[InstanceToken.Status];
end;

function TAureliusInstanceData.VariableValue(InstanceVar: TVariableEntity): TValue;
begin
  if Trim(InstanceVar.ValueType) = '' then
    Exit(TValue.Empty);

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
    if ProcessId <> '' then
    begin
      Definition := Manager.Find<TProcessDefinitionEntity>(ProcessId);
      if Definition = nil then
        raise EOctopusDefinitionNotFound.Create(ProcessId);
    end
    else
      Definition := nil;

    Instance := TProcessInstanceEntity.Create;
    Manager.AddToGarbage(Instance);
    Instance.CreatedOn := Now;
    Instance.ProcessDefinition := Definition;
    Manager.Save(Instance);

    Result := TAureliusInstanceData.Create(Pool, Instance.Id);
  finally
    Manager.Free;
  end;
end;

{ TAureliusRepository }

function TAureliusRepository.GetDefinition(
  const ProcessId: string): TWorkflowProcess;
var
  Manager: TObjectManager;
  Definition: TProcessDefinitionEntity;
begin
  Result := nil;
  if Assigned(FOnGetProcessFromId) then
  begin
    FOnGetProcessFromId(ProcessId, Result);
    if Result <> nil then Exit;
  end;

  Manager := CreateManager;
  try
    Definition := Manager.Find<TProcessDefinitionEntity>(ProcessId);
    if Definition = nil then
      raise EOctopusDefinitionNotFound.Create(ProcessId);

    if Definition.Process.AsUnicodeString <> '' then
    begin
      Result := TWorkflowDeserializer.ProcessFromJson(Definition.Process.AsUnicodeString);
      Exit;
    end;

    raise EOctopusException.CreateFmt('Could not retrieve process definition "%s"', [ProcessId]);
  finally
    Manager.Free;
  end;
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
      if VarIsNull(VersionResult.Values[0]) then
        NextVersion := 1
      else
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
    if Process <> nil then
      Definition.Process.AsUnicodeString :=  TWorkflowSerializer.ProcessToJson(Process);
    Manager.Save(Definition);
    Result := Definition.Id;
  finally
    Manager.Free;
  end;
end;

end.
