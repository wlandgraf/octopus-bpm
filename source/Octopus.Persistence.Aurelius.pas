unit Octopus.Persistence.Aurelius;

{$I Octopus.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
  System.TypInfo,
  Generics.Collections,
  Aurelius.Criteria.Base,
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
    FManager: TObjectManager;
  protected
    function CreateManager: TObjectManager;
    function Manager: TObjectManager;
    property Pool: IDBConnectionPool read FPool;
  public
    constructor Create(APool: IDBConnectionPool);
    destructor Destroy; override;
  end;

  TAureliusInstanceData = class(TAureliusPersistence, IProcessInstanceData, ITokensPersistence)
  private
    FInstanceId: string;
    procedure SaveToken(Token: TToken);
    function TokenFromEntity(InstanceToken: TTokenEntity): TToken;
    function GetInstanceEntity(Manager: TObjectManager): TProcessInstanceEntity;
  public
    constructor Create(Pool: IDBConnectionPool; const InstanceId: string);
    destructor Destroy; override;
  public
    { IProcessInstanceData methods }
    function GetInstanceId: string;
    function AddToken(Node: TFlowNode): string; overload;
    function AddToken(Transition: TTransition; const ParentId: string): string; overload;
    function LoadTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    procedure Lock(TimeoutMS: Integer);
    procedure Unlock;
    procedure Finish;
    procedure SetDueDate(DueDate: TDateTime);
  end;

  TAureliusInstanceService = class(TAureliusPersistence, IOctopusInstanceService)
  private
    FInstanceId: string;
    procedure FillVariable(InstanceVar: TVariableEntity; Value: TValue);
    function GetInstanceEntity(Manager: TObjectManager): TProcessInstanceEntity;
  public
    constructor Create(Pool: IDBConnectionPool; const InstanceId: string);
  public
    { IOctopusInstanceService methods }
    function LoadVariables: TArray<IVariable>;
    function LoadVariable(const Name: string; const TokenId: string = ''): IVariable;
    procedure SaveVariable(const Name: string; const Value: TValue; const TokenId: string = '');
  end;

  TAureliusRepository = class(TAureliusPersistence, IOctopusRepository)
  strict private
    FProcessFactory: IOctopusProcessFactory;
  public
    constructor Create(Pool: IDBConnectionPool; ProcessFactory: IOctopusProcessFactory); overload;
    function PublishDefinition(const Key, Process: string; const Name: string = ''): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
    function FindDefinitionByKey(const Key: string): IProcessDefinition;
  end;

  TAureliusRuntime = class(TAureliusPersistence, IOctopusRuntime)
  public
    function CreateInstance(const ProcessId, Reference: string): string;
    function GetInstanceProcessId(const InstanceId: string): string;
    function CreateInstanceQuery: IInstanceQuery;
    function GetPendingInstances: TArray<IProcessInstance>;
  end;

  TAureliusInstanceQuery = class(TAureliusPersistence, IInstanceQuery)
  strict private
    FInstanceId: string;
    FReference: string;
    FVariables: TList<TCustomCriterion>;
    procedure BuildCriteria(Criteria: TCriteria);
    procedure AddVariable(const Expr: TCustomCriterion);
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    function InstanceId(const AInstanceId: string): IInstanceQuery;
    function Reference(const AReference: string): IInstanceQuery;
    function VariableValueEquals(const AName: string; const AValue: TValue): IInstanceQuery;
    function Results: TArray<IProcessInstance>;
  end;

  TAureliusProcessDefinition = class(TInterfacedObject, IProcessDefinition)
  strict private
    FId: string;
    FKey: string;
    FName: string;
    FProcess: string;
    FVersion: Integer;
    FCreatedOn: TDateTime;
    function GetId: string;
    function GetKey: string;
    function GetName: string;
    function GetProcess: string;
    function GetVersion: Integer;
    function GetCreatedOn: TDateTime;
  public
    constructor Create(Entity: TProcessDefinitionEntity);
    property Id: string read GetId;
    property Key: string read GetKey;
    property Name: string read GetName;
    property Process: string read GetProcess;
    property Version: Integer read GetVersion;
    property CreatedOn: TDateTime read GetCreatedOn;
  end;

  TAureliusProcessInstance = class(TInterfacedObject, IProcessInstance)
  strict private
    FId: string;
    FProcessId: string;
    FReference: string;
    FCreatedOn: TDateTime;
    FFinishedOn: TDateTime;
    function GetId: string;
    function GetProcessId: string;
    function GetReference: string;
    function GetCreatedOn: TDateTime;
    function GetFinishedOn: TDateTime;
  public
    constructor Create(Entity: TProcessInstanceEntity);
    property Id: string read GetId;
    property ProcessId: string read GetProcessId;
    property Reference: string read GetReference;
    property CreatedOn: TDateTime read GetCreatedOn;
    property FinishedOn: TDateTime read GetFinishedOn;
  end;

  TAureliusVariable = class(TInterfacedObject, IVariable)
  strict private
    FName: string;
    FValue: TValue;
    FTokenId: string;
    function GetName: string;
    function GetValue: TValue;
    function GetTokenId: string;
    function ToValue(Variable: TVariableEntity): TValue;
  public
    constructor Create(Variable: TVariableEntity); reintroduce;
    property Name: string read GetName;
    property Value: TValue read GetValue;
    property TokenId: string read GetTokenId;
  end;

implementation

uses
  System.Variants,
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
begin
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
end;

function TAureliusInstanceData.AddToken(Transition: TTransition; const ParentId: string): string;
var
  token: TToken;
begin
  token := TToken.Create;
  try
    token.TransitionId := Transition.Id;
    Assert(Transition.Target <> nil);
    token.NodeId := Transition.Target.Id;
    token.ParentId := ParentId;
    SaveToken(token);
    Result := token.Id;
  finally
    token.Free;
  end;
end;

function TAureliusInstanceData.AddToken(Node: TFlowNode): string;
var
  token: TToken;
begin
  token := TToken.Create;
  try
    token.NodeId := Node.Id;
  //  token.ProducerId := ProducerId;
    SaveToken(token);
    Result := token.Id;
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
begin
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
end;

destructor TAureliusInstanceData.Destroy;
begin
  inherited;
end;

procedure TAureliusInstanceData.Finish;
var
  Instance: TProcessInstanceEntity;
begin
  Instance := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Instance = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);

  Instance.Status := TProcessInstanceStatus.Finished;
  Instance.DueDate := SNull;
  Manager.Flush(Instance);
end;

function TAureliusInstanceData.GetInstanceEntity(
  Manager: TObjectManager): TProcessInstanceEntity;
begin
  Result := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Result = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);
end;

function TAureliusInstanceData.GetInstanceId: string;
begin
  Result := FInstanceId;
end;

function TAureliusInstanceData.LoadTokens: TList<TToken>;
var
  tokenList: TList<TTokenEntity>;
  I: Integer;
begin
  // Most recent tokens first
  tokenList := Manager.Find<TTokenEntity>
    .CreateAlias('Instance', 'i')
    .Where(Linq['i.Id'] = FInstanceId)
    .OrderBy(Linq['CreatedOn'])
    .List;
  try
    Result := TObjectList<TToken>.Create;
    try
      for I := 0 to tokenList.Count - 1 do
        Result.Add(TokenFromEntity(tokenList[I]));
    except
      Result.Free;
      raise;
    end;
  finally
    tokenList.Free;
  end;
end;

procedure TAureliusInstanceData.Lock(TimeoutMS: Integer);
var
  Instance: TProcessInstanceEntity;
begin
  Instance := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Instance = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);

  if Instance.LockExpiration.HasValue and (Now <= Instance.LockExpiration.ValueOrDefault) then
    raise EOctopusInstanceLockFailed.Create(FInstanceId);

  Instance.LockExpiration := IncMillisecond(Now, TimeoutMS);
  Manager.Flush(Instance);
end;

procedure TAureliusInstanceData.RemoveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
begin
  tokenEnt := Manager.Find<TTokenEntity>(Token.Id);
  if tokenEnt = nil then
    raise EOctopusTokenNotFound.CreateFmt(SErrorFinishTokenNotFound, [Token.Id]);

  if tokenEnt.Status = TTokenEntityStatus.Finished then
    Exit;

  tokenEnt.FinishedOn := Now;
  tokenEnt.Status := TTokenEntityStatus.Finished;
//    tokenEnt.ConsumerId := ConsumerId;
  Manager.Flush(tokenEnt);
end;

procedure TAureliusInstanceData.SaveToken(Token: TToken);
var
  tokenEnt: TTokenEntity;
begin
  tokenEnt := TTokenEntity.Create;
  Manager.AddOwnership(tokenEnt);
  tokenEnt.Status := TTokenEntityStatus.Active;
  tokenEnt.CreatedOn := Now;
  tokenEnt.TransitionId := Token.TransitionId;
  tokenEnt.NodeId := Token.NodeId;
  tokenEnt.Instance := GetInstanceEntity(Manager);
  tokenEnt.Parent := Manager.Find<TTokenEntity>(Token.ParentId);
  Manager.Save(tokenEnt);
  Token.Id := tokenEnt.Id;
end;

procedure TAureliusInstanceData.SetDueDate(DueDate: TDateTime);
var
  Instance: TProcessInstanceEntity;
begin
  Instance := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Instance = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);

  Instance.DueDate := DueDate;
  Manager.Flush(Instance);
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
  Result.ParentId := InstanceToken.ParentId;
  Result.Status := TokenStatusMap[InstanceToken.Status];
end;

procedure TAureliusInstanceData.Unlock;
var
  Instance: TProcessInstanceEntity;
begin
  Instance := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Instance = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);

  Instance.LockExpiration := SNull;
  Manager.Flush(Instance);
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

destructor TAureliusPersistence.Destroy;
begin
  FManager.Free;
  inherited;
end;

function TAureliusPersistence.Manager: TObjectManager;
begin
  if FManager = nil then
    FManager := CreateManager;
  Result := FManager;
end;

{ TAureliusRuntime }

function TAureliusRuntime.CreateInstance(
  const ProcessId, Reference: string): string;
var
  Manager: TObjectManager;
  Instance: TProcessInstanceEntity;
  Definition: TProcessDefinitionEntity;
begin
  Manager := CreateManager;
  try
//    if ProcessId <> '' then
//    begin
      Definition := Manager.Find<TProcessDefinitionEntity>(ProcessId);
      if Definition = nil then
        raise EOctopusDefinitionNotFound.Create(ProcessId);
//    end
//    else
//      Definition := nil;

    Instance := TProcessInstanceEntity.Create;
    Manager.AddOwnership(Instance);
    Instance.CreatedOn := Now;
    Instance.ProcessDefinition := Definition;
    if Reference <> '' then
      Instance.Reference := Reference;
    Manager.Save(Instance);

    Result := Instance.Id;
  finally
    Manager.Free;
  end;
end;

function TAureliusRuntime.CreateInstanceQuery: IInstanceQuery;
begin
  Result := TAureliusInstanceQuery.Create(Pool);
end;

function TAureliusRuntime.GetInstanceProcessId(
  const InstanceId: string): string;
var
  Manager: TObjectManager;
  Instance: TProcessInstanceEntity;
begin
  Manager := CreateManager;
  try
    Instance := Manager.Find<TProcessInstanceEntity>(InstanceId);
    if Instance = nil then
      raise EOctopusInstanceNotFound.Create(InstanceId);

    if Instance.ProcessDefinition <> nil then
      Result := Instance.ProcessDefinition.Id
    else
      Result := '';
  finally
    Manager.Free;
  end;
end;

function TAureliusRuntime.GetPendingInstances: TArray<IProcessInstance>;
const
  MaxAcquiredInstances = 5;
var
  Manager: TObjectManager;
  Entities: TList<TProcessInstanceEntity>;
  LockDue: TDateTime;
  Entity: TProcessInstanceEntity;
  InstanceIds: TList<IProcessInstance>;
begin
  InstanceIds := nil;
  Manager := CreateManager;
  try
    InstanceIds := TList<IProcessInstance>.Create;
    LockDue := Now;
    Entities := Manager.Find<TProcessInstanceEntity>
      .Take(MaxAcquiredInstances)
      .Where(Linq['LockExpiration'].IsNull or (Linq['LockExpiration'] < LockDue))
      .Where(Linq['DueDate'].IsNull or (Linq['DueDate'] <= LockDue))
      .Where(Linq['Status'] <> TProcessInstanceStatus.Finished)
      .OrderBy(TProjections.Condition(Linq['DueDate'].IsNull, Linq.Literal<Integer>(0), Linq.Literal<Integer>(1)))
      .OrderBy('DueDate')
      .List;
    try
      for Entity in Entities do
        InstanceIds.Add(TAureliusProcessInstance.Create(Entity));
    finally
      Entities.Free;
    end;
    Result := InstanceIds.ToArray;
  finally
    InstanceIds.Free;
    Manager.Free;
  end;
end;

{ TAureliusRepository }

constructor TAureliusRepository.Create(Pool: IDBConnectionPool;
  ProcessFactory: IOctopusProcessFactory);
begin
  inherited Create(Pool);
  FProcessFactory := ProcessFactory;
end;

function TAureliusRepository.GetDefinition(const ProcessId: string): TWorkflowProcess;
var
  Manager: TObjectManager;
  Definition: TProcessDefinitionEntity;
  ProcessJson: string;
begin
  Result := nil;
  Manager := CreateManager;
  try
    Definition := Manager.Find<TProcessDefinitionEntity>(ProcessId);
    if Definition = nil then
      raise EOctopusDefinitionNotFound.Create(ProcessId);

    ProcessJson := TEncoding.UTF8.GetString(Definition.Process.AsBytes);
    if ProcessJson <> '' then
      Result := TWorkflowDeserializer.ProcessFromJson(ProcessJson)
    else
    if FProcessFactory <> nil then
      FProcessFactory.GetProcessDefinition(Definition.Id, Result);

    if Result = nil then
      raise EOctopusException.CreateFmt('Could not retrieve process definition "%s"', [ProcessId]);
  finally
    Manager.Free;
  end;
end;

function TAureliusRepository.FindDefinitionByKey(
  const Key: string): IProcessDefinition;
var
  Manager: TObjectManager;
  Definition: TProcessDefinitionEntity;
begin
  Result := nil;
  Manager := CreateManager;
  try
    Definition := Manager.Find<TProcessDefinitionEntity>
      .Where(Linq['Key'] = LowerCase(Key))
      .OrderBy('Version', False)
      .Take(1)
      .UniqueResult;

    if Definition <> nil then
      Result := TAureliusProcessDefinition.Create(Definition)
  finally
    Manager.Free;
  end;
end;

function TAureliusRepository.PublishDefinition(const Key, Process: string;
  const Name: string = ''): string;
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
      .Where(Linq['Key'] = LowerCase(Key))
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
    Manager.AddOwnership(Definition);
    Definition.Key := LowerCase(Key);
    Definition.Name := Name;
    Definition.Version := NextVersion;
    Definition.Status := TProcessDefinitionStatus.Published;
    Definition.CreatedOn := Now;

    if Process <> '' then
      Definition.Process.AsBytes := TEncoding.UTF8.GetBytes(Process);
    Manager.Save(Definition);
    Result := Definition.Id;
  finally
    Manager.Free;
  end;
end;

{ TAureliusProcessDefinition }

constructor TAureliusProcessDefinition.Create(Entity: TProcessDefinitionEntity);
begin
  inherited Create;
  FId := Entity.Id;
  FKey := Entity.Key;
  FName := Entity.Name;
  FProcess := TEncoding.UTF8.GetString(Entity.Process.AsBytes);
  FVersion := Entity.Version;
  FCreatedOn := Entity.CreatedOn;
end;

function TAureliusProcessDefinition.GetCreatedOn: TDateTime;
begin
  Result := FCreatedOn;
end;

function TAureliusProcessDefinition.GetId: string;
begin
  Result := FId;
end;

function TAureliusProcessDefinition.GetKey: string;
begin
  Result := FKey;
end;

function TAureliusProcessDefinition.GetName: string;
begin
  Result := FName;
end;

function TAureliusProcessDefinition.GetProcess: string;
begin
  Result := FProcess;
end;

function TAureliusProcessDefinition.GetVersion: Integer;
begin
  Result := FVersion;
end;

{ TAureliusVariable }

constructor TAureliusVariable.Create(Variable: TVariableEntity);
begin
  inherited Create;
  FName := Variable.Name;
  FValue := ToValue(Variable);
  FTokenId := Variable.TokenId;
end;

function TAureliusVariable.GetName: string;
begin
  Result := FName;
end;

function TAureliusVariable.GetTokenId: string;
begin
  Result := FTokenId;
end;

function TAureliusVariable.GetValue: TValue;
begin
  Result := FValue;
end;

function TAureliusVariable.ToValue(Variable: TVariableEntity): TValue;
begin
  if Trim(Variable.ValueType) = '' then
    Exit(TValue.Empty);

  if Trim(Variable.Value) <> '' then
    result := TWorkflowDeserializer.ValueFromJson(Variable.Value,
      TOctopusDataTypes.Default.Get(Variable.ValueType).NativeType)
  else
    result := TValue.Empty;
end;

{ TAureliusInstanceSerice }

constructor TAureliusInstanceService.Create(Pool: IDBConnectionPool;
  const InstanceId: string);
begin
  inherited Create(Pool);
  FInstanceId := InstanceId;
end;

procedure TAureliusInstanceService.FillVariable(InstanceVar: TVariableEntity;
  Value: TValue);
var
  dataType: TOctopusDataType;
begin
  if Value.TypeInfo <> nil then
  begin
    InstanceVar.ClearValue;
    dataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);
    InstanceVar.Value := TWorkflowSerializer.ValueToJson(Value, dataType.NativeType);
    InstanceVar.ValueType := dataType.Name;
    {.$MESSAGE WARN 'Review this'}
    if Value.TypeInfo.Kind in [tkString, tkLString, tkWString, tkUString, tkChar, tkWChar] then
      InstanceVar.StringValue := Value.AsString;
  end
  else
  begin
    InstanceVar.Value := '';
    InstanceVar.ValueType := '';
  end;
end;

function TAureliusInstanceService.GetInstanceEntity(
  Manager: TObjectManager): TProcessInstanceEntity;
begin
  Result := Manager.Find<TProcessInstanceEntity>(FInstanceId);
  if Result = nil then
    raise EOctopusInstanceNotFound.Create(FInstanceId);
end;

function TAureliusInstanceService.LoadVariable(const Name,
  TokenId: string): IVariable;
var
  varEnt: TVariableEntity;
  Criteria: TCriteria<TVariableEntity>;
begin
  Criteria := Manager.Find<TVariableEntity>
    .CreateAlias('Instance', 'i')
    .CreateAlias('Token', 't')
    .Where((Linq['i.Id'] = FInstanceId)
       and (Linq['Name'] = LowerCase(Name)));

  if TokenId <> '' then
    Criteria.Add(Linq['t.Id'] = tokenId)
  else
    Criteria.Add(Linq['t.Id'].IsNull);

  varEnt := Criteria.UniqueResult;

  if varEnt <> nil then
    Result := TAureliusVariable.Create(varEnt)
  else
    Result := nil
end;

function TAureliusInstanceService.LoadVariables: TArray<IVariable>;
var
  List: TList<TVariableEntity>;
  I: Integer;
begin
  List := Manager.Find<TVariableEntity>
    .CreateAlias('Instance', 'i')
    .Where(Linq['i.Id'] = FInstanceId)
    .List;
  try
    SetLength(Result, List.Count);
    for I := 0 to List.Count - 1 do
      Result[I] := TAureliusVariable.Create(List[I]);
  finally
    List.Free;
  end;
end;

procedure TAureliusInstanceService.SaveVariable(const Name: string;
  const Value: TValue; const TokenId: string);
var
  tokenEnt: TTokenEntity;
  varEnt: TVariableEntity;
  Criteria: TCriteria<TVariableEntity>;
begin
  Criteria := Manager.Find<TVariableEntity>
    .CreateAlias('Instance', 'i')
    .CreateAlias('Token', 't')
    .Where((Linq['i.Id'] = FInstanceId)
       and (Linq['Name'] = LowerCase(Name)));

  if TokenId <> '' then
    Criteria.Add(Linq['t.Id'] = tokenId)
  else
    Criteria.Add(Linq['t.Id'].IsNull);

  varEnt := Criteria.UniqueResult;

  if varEnt = nil then
  begin
    varEnt := TVariableEntity.Create;
    Manager.AddOwnership(varEnt);
    varEnt.Instance := GetInstanceEntity(Manager);
    varEnt.Name := LowerCase(Name);
    if TokenId <> '' then
    begin
      tokenEnt := Manager.Find<TTokenEntity>(TokenId);
      if tokenEnt = nil then
        raise EOctopusTokenNotFound.CreateFmt(SErrorSetVariableTokenNotFound, [Name, TokenId]);
      varEnt.Token := tokenEnt;
    end;
    FillVariable(varEnt, Value);
    Manager.Save(varEnt);
  end
  else
  begin
    FillVariable(varEnt, Value);
    Manager.Flush(varEnt);
  end;
end;

{ TAureliusInstanceQuery }

procedure TAureliusInstanceQuery.AddVariable(const Expr: TCustomCriterion);
begin
  FVariables.Add(Expr);
end;

procedure TAureliusInstanceQuery.AfterConstruction;
begin
  inherited;
  FVariables := TObjectList<TCustomCriterion>.Create;
end;

procedure TAureliusInstanceQuery.BeforeDestruction;
begin
  FVariables.Free;
  inherited;
end;

procedure TAureliusInstanceQuery.BuildCriteria(Criteria: TCriteria);
begin
  if FInstanceId <> '' then
    Criteria.Add(Linq['Id'] = FInstanceId);
  if FReference <> '' then
    Criteria.Add(Linq['Reference'] = FReference);
  while FVariables.Count > 0 do
    Criteria.Add(FVariables.Extract(FVariables[0]));
end;

function TAureliusInstanceQuery.InstanceId(
  const AInstanceId: string): IInstanceQuery;
begin
  FInstanceId := AInstanceId;
  Result := Self;
end;

function TAureliusInstanceQuery.Reference(
  const AReference: string): IInstanceQuery;
begin
  FReference := AReference;
  Result := Self;
end;

function TAureliusInstanceQuery.Results: TArray<IProcessInstance>;
var
  Criteria: TCriteria<TProcessInstanceEntity>;
  Manager: TObjectManager;
  Entities: TList<TProcessInstanceEntity>;
  I: Integer;
begin
  Criteria := nil;
  Manager := CreateManager;
  try
    Criteria := Manager.Find<TProcessInstanceEntity>;
    Criteria.AutoDestroy := False;
    BuildCriteria(Criteria);
    Entities := Criteria.List;
    try
      SetLength(Result, Entities.Count);
      for I := 0 to Entities.Count - 1 do
        Result[I] := TAureliusProcessInstance.Create(Entities[I]);
    finally
      Entities.Free;
    end;
  finally
    Criteria.Free;
    Manager.Free;
  end;
end;

function TAureliusInstanceQuery.VariableValueEquals(const AName: string; const AValue: TValue): IInstanceQuery;
var
  ValueCondition: string;
  StringValue: string;
begin
  if not (AValue.TypeInfo.Kind in [tkString, tkLString, tkWString, tkUString, tkChar, tkWChar]) then
    {.$MESSAGE WARN 'Review this'}
    raise Exception.Create('Can only search for string variables');

  ValueCondition := 'STRING_VALUE = ?';
  StringValue := AValue.AsString;

  AddVariable(
    Linq.Sql<string, string>(Format(
      'EXISTS (SELECT 1 FROM OCT_VARIABLE ' +
      'WHERE (PROC_INSTANCE_ID = {Id}) AND ' +
      '  (UPPER(NAME) = UPPER(?)) AND (TOKEN_ID IS NULL) AND (%s))',
      [ValueCondition]),
      AName, StringValue)
  );
  Result := Self;
end;

{ TAureliusProcessInstance }

constructor TAureliusProcessInstance.Create(Entity: TProcessInstanceEntity);
begin
  inherited Create;
  FId := Entity.Id;
  FProcessId := Entity.ProcessId;
  FReference := Entity.Reference.ValueOrDefault;
  FCreatedOn := Entity.CreatedOn;
  FFinishedOn := Entity.FinishedOn.ValueOrDefault;
end;

function TAureliusProcessInstance.GetCreatedOn: TDateTime;
begin
  Result := FCreatedOn;
end;

function TAureliusProcessInstance.GetFinishedOn: TDateTime;
begin
  Result := FFinishedOn;
end;

function TAureliusProcessInstance.GetId: string;
begin
  Result := FId;
end;

function TAureliusProcessInstance.GetProcessId: string;
begin
  Result := FProcessId;
end;

function TAureliusProcessInstance.GetReference: string;
begin
  Result := FReference;
end;

end.
