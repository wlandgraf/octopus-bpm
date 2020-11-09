unit Octopus.Persistence.Instance;

interface

uses
  System.SysUtils,
  System.Rtti,
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Explorer,
  Octopus.Entities,
  Octopus.Process;

type
  TProcessInstance = class(TInterfacedObject, IProcessInstanceData)
  private
    FManager: TObjectManager;
    FInstance: TOctopusProcessInstance;
    FProcess: TWorkflowProcess;
    FActiveTokens: TDictionary<TToken,TOctopusInstanceToken>;
    procedure LoadActiveTokens;
    procedure SaveToken(Token: TToken);
    procedure SaveVariable(InstanceVar: TOctopusInstanceVariable; Value: TValue);
    function TokenFromEntity(InstanceToken: TOctopusInstanceToken): TToken;
    function VariableValue(InstanceVar: TOctopusInstanceVariable): TValue;
  public
    constructor Create(Connection: IDBConnection; Process: TWorkflowProcess; const InstanceId: string);
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

implementation

uses
  Aurelius.Criteria.Linq,
  Aurelius.Criteria.Projections,
  Octopus.DataTypes,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer;

{ TProcessInstance }

procedure TProcessInstance.AddToken(Transition: TTransition);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Transition := Transition;
  SaveToken(token);
end;

procedure TProcessInstance.AddToken(Node: TFlowNode);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Node := Node;
  SaveToken(token);
end;

function TProcessInstance.CountTokens: integer;
begin
  result := FActiveTokens.Count;
end;

constructor TProcessInstance.Create(Connection: IDBConnection; Process: TWorkflowProcess; const InstanceId: string);
begin
  FManager := TObjectManager.Create(Connection, TMappingExplorer.Get(OctopusModel));
  FActiveTokens := TDictionary<TToken,TOctopusInstanceToken>.Create;

  FProcess := Process;
  FInstance := FManager.Find<TOctopusProcessInstance>(InstanceId);

  LoadActiveTokens;
end;

destructor TProcessInstance.Destroy;
begin
  FManager.Free;
  FActiveTokens.Free;
  inherited;
end;

function TProcessInstance.GetLocalVariable(Token: TToken; const Name: string): TValue;
var
  tokenEnt: TOctopusInstanceToken;
  varEnt: TOctopusInstanceVariable;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    varEnt := FManager.Find<TOctopusInstanceVariable>
      .Where((Linq['Instance'] = FInstance.Id)
         and (Linq['Token'] = tokenEnt.Id)
         and (Linq['Name'] = Name))
      .UniqueResult;

    if varEnt <> nil then
      exit(VariableValue(varEnt));
  end;
  result := TValue.Empty;
end;

function TProcessInstance.GetTokens: TArray<TToken>;
begin
  result := FActiveTokens.Keys.ToArray;
end;

function TProcessInstance.GetTokens(Node: TFlowNode): TArray<TToken>;
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

function TProcessInstance.GetVariable(const Name: string): TValue;
var
  varEnt: TOctopusInstanceVariable;
begin
  varEnt := FManager.Find<TOctopusInstanceVariable>
    .Where((Linq['Instance'] = FInstance.Id)
       and (Linq['Token'].IsNull)
       and (Linq['Name'] = Name))
    .UniqueResult;

  if varEnt <> nil then
    result := VariableValue(varEnt)
  else
    result := TValue.Empty;
end;

function TProcessInstance.LastToken(Node: TFlowNode): TToken;
var
  tokenList: TList<TOctopusInstanceToken>;
begin
  tokenList := FManager.Find<TOctopusInstanceToken>
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

procedure TProcessInstance.LoadActiveTokens;
var
  tokenList: TList<TOctopusInstanceToken>;
  tokenEnt: TOctopusInstanceToken;
begin
  FActiveTokens.Clear;

  tokenList := FManager.Find<TOctopusInstanceToken>
    .Where((Linq['Instance'] = FInstance.Id)
        and Linq['FinishedOn'].IsNull)
    .List;

  for tokenEnt in tokenList do
    FActiveTokens.Add(TokenFromEntity(tokenEnt), tokenEnt);
end;

procedure TProcessInstance.RemoveToken(Token: TToken);
var
  tokenEnt: TOctopusInstanceToken;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    tokenEnt.FinishedOn := Now; // TODO
    FManager.Flush;
    FActiveTokens.Remove(Token);
  end;
end;

procedure TProcessInstance.SaveToken(Token: TToken);
var
  tokenEnt: TOctopusInstanceToken;
begin
  tokenEnt := TOctopusInstanceToken.Create;
  tokenEnt.CreatedOn := Now; // TODO
  if Token.Transition <> nil then
    tokenEnt.TransitionId := Token.Transition.Id;
  tokenEnt.NodeId := Token.Node.Id;
  tokenEnt.NodeClass := Token.Node.QualifiedClassName;

  FManager.Save(tokenEnt);
end;

procedure TProcessInstance.SaveVariable(InstanceVar: TOctopusInstanceVariable; Value: TValue);
var
  dataType: TOctopusDataType;
begin
  dataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);

  InstanceVar.Value.AsString := TWorkflowSerializer.ValueToJson(Value, dataType.NativeType);
  InstanceVar.ValueType := dataType.Name;

  FManager.SaveOrUpdate(InstanceVar);
end;

procedure TProcessInstance.SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
var
  tokenEnt: TOctopusInstanceToken;
  varEnt: TOctopusInstanceVariable;
begin
  if FActiveTokens.TryGetValue(Token, tokenEnt) then
  begin
    varEnt := FManager.Find<TOctopusInstanceVariable>
      .Where((Linq['Instance'] = FInstance.Id)
         and (Linq['Token'] = tokenEnt.Id)
         and (Linq['Name'] = Name))
      .UniqueResult;

    if varEnt = nil then
    begin
      varEnt := TOctopusInstanceVariable.Create;
      varEnt.Instance := FInstance;
      varEnt.Token := tokenEnt;
      varEnt.Name := Name;
    end;

    SaveVariable(varEnt, Value);
  end;
end;

procedure TProcessInstance.SetVariable(const Name: string; const Value: TValue);
var
  varEnt: TOctopusInstanceVariable;
begin
  varEnt := FManager.Find<TOctopusInstanceVariable>
    .Where((Linq['Instance'] = FInstance.Id)
       and (Linq['Token'].IsNull)
       and (Linq['Name'] = Name))
    .UniqueResult;

  if varEnt = nil then
  begin
    varEnt := TOctopusInstanceVariable.Create;
    varEnt.Instance := FInstance;
    varEnt.Name := Name;
  end;

  SaveVariable(varEnt, Value);
end;

function TProcessInstance.TokenFromEntity(InstanceToken: TOctopusInstanceToken): TToken;
begin
  result := TToken.Create;
  if not InstanceToken.TransitionId.IsNull then
    result.Transition := FProcess.GetTransition(InstanceToken.TransitionId)
  else
    result.Node := FProcess.GetNode(InstanceToken.NodeId);
end;

function TProcessInstance.VariableValue(InstanceVar: TOctopusInstanceVariable): TValue;
begin
  if not InstanceVar.Value.IsNull then
    result := TWorkflowDeserializer.ValueFromJson(InstanceVar.Value.AsString,
      TOctopusDataTypes.Default.Get(InstanceVar.ValueType).NativeType)
  else
    result := TValue.Empty;
end;

end.
