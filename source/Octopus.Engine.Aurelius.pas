unit Octopus.Engine.Aurelius;

interface

uses
  System.Rtti,
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Octopus.Persistence.Common,
  Octopus.Persistence.Aurelius,
  Octopus.Process,
  Octopus.Engine,
  Octopus.Engine.Runner;

type
  IAureliusStorage = interface(IStorage)
  ['{B44D57EE-E5CC-4B7E-BFDA-57A5C635003A}']
    function GetPool: IDBConnectionPool;
    property Pool: IDBConnectionPool read GetPool;
  end;

  TAureliusStorage = class(TInterfacedObject, IAureliusStorage)
  strict private
    FPool: IDBConnectionPool;
    function GetPool: IDBConnectionPool;
  public
    constructor Create(APool: IDBConnectionPool);
    property Pool: IDBConnectionPool read GetPool;
  end;

  TAureliusOctopusEngine = class(TInterfacedObject, IOctopusEngine)
  strict private
    FPool: IDBConnectionPool;
    FProcessFactory: IOctopusProcessFactory;
    FLockTimeoutMS: Integer;
    FDueDateIntervalMS: Int64;
    function CreateRepository(Pool: IDBConnectionPool): IOctopusRepository;
    function CreateRuntime(Pool: IDBConnectionPool): IOctopusRuntime;
    function CreateInstanceService(const InstanceId: string): IOctopusInstanceService;
    procedure RunInstance(Process: TWorkflowProcess; Instance: IProcessInstanceData;
      Variables: IVariablesPersistence; Connection: IDBConnection); overload;
    function CreateSingletonPool: IDBConnectionPool;
    procedure ValidateDefinition(const ProcessJson: string);
  public
    constructor Create(APool: IDBConnectionPool); overload;
    constructor Create(APool: IDBConnectionPool; AProcessFactory: IOctopusProcessFactory); overload;
//    property Pool: IDBConnectionPool read FPool;
  public
    { IOctopusEngine methods }
    function PublishDefinition(const Key, Process: string; const Name: string = ''): string;
    function FindDefinitionByKey(const Key: string): IProcessDefinition;

    function CreateInstance(const ProcessId: string): string; overload;
    function CreateInstance(const ProcessId: string; Variables: TEnumerable<TVariable>): string; overload;
    function CreateInstance(const ProcessId, Reference: string): string; overload;
    function CreateInstance(const ProcessId, Reference: string; Variables: TEnumerable<TVariable>): string; overload;
    procedure RunInstance(const InstanceId: string); overload;

    procedure SetVariable(const InstanceId, VariableName: string; const Value: TValue);
    function GetVariable(const InstanceId, VariableName: string): IVariable;
    function FindInstances: IInstanceQuery;

    procedure RunPendingInstances;

    property DueDateIntervalMS: Int64 read FDueDateIntervalMS write FDueDateIntervalMS;
  end;

implementation

uses
  Octopus.Json.Deserializer,
  Octopus.Engine.Variables,
  Octopus.Process.Validation,
  Aurelius.Drivers.Base;

{ TAureliusOctopusEngine }

constructor TAureliusOctopusEngine.Create(APool: IDBConnectionPool);
begin
  Create(APool, nil);
end;

constructor TAureliusOctopusEngine.Create(APool: IDBConnectionPool;
  AProcessFactory: IOctopusProcessFactory);
begin
  inherited Create;
  FLockTimeoutMS := 5 * 60 * 1000; // 5 minutes
  FDueDateIntervalMS := 30 * 60 * 1000; // 30 minutes
  FPool := APool;
  FProcessFactory := AProcessFactory;
end;

function TAureliusOctopusEngine.CreateInstance(const ProcessId,
  Reference: string; Variables: TEnumerable<TVariable>): string;
var
  Runtime: IOctopusInstanceService;
  Instance: IProcessInstanceData;
  VariablesPersistence: IVariablesPersistence;
  Process: TWorkflowProcess;
  Variable: TVariable;
  SingletonPool: IDBConnectionPool;
  Trans: IDBTransaction;
begin
  SingletonPool := CreateSingletonPool;
  Trans := SingletonPool.GetConnection.BeginTransaction;
  try
    Process := CreateRepository(SingletonPool).GetDefinition(ProcessId);
    try
      Result := CreateRuntime(SingletonPool).CreateInstance(ProcessId, Reference);
      Runtime := TAureliusInstanceService.Create(SingletonPool, Result);
      Instance := TAureliusInstanceData.Create(SingletonPool, Result);
      VariablesPersistence := TContextVariables.Create(Runtime);
      Process.InitInstance(Instance, VariablesPersistence);
    finally
      Process.Free;
    end;
    if Variables <> nil then
      for Variable in Variables do
        VariablesPersistence.SaveVariable(Variable.Name, Variable.Value);
    Trans.Commit;
  except
    Trans.Rollback;
    raise;
  end;

end;

function TAureliusOctopusEngine.CreateInstanceService(const InstanceId: string): IOctopusInstanceService;
begin
  Result := TAureliusInstanceService.Create(FPool, InstanceId);
end;

function TAureliusOctopusEngine.CreateInstance(const ProcessId,
  Reference: string): string;
begin
  Result := CreateInstance(ProcessId, Reference, nil);
end;

function TAureliusOctopusEngine.CreateInstance(const ProcessId: string): string;
begin
  Result := CreateInstance(ProcessId, '', nil);
end;

function TAureliusOctopusEngine.CreateInstance(const ProcessId: string;
  Variables: TEnumerable<TVariable>): string;
begin
  Result := CreateInstance(ProcessId, '', Variables);
end;

function TAureliusOctopusEngine.CreateRepository(Pool: IDBConnectionPool): IOctopusRepository;
begin
  Result := TAureliusRepository.Create(Pool, FProcessFactory);
end;

function TAureliusOctopusEngine.CreateRuntime(Pool: IDBConnectionPool): IOctopusRuntime;
begin
  Result := TAureliusRuntime.Create(Pool);
end;

function TAureliusOctopusEngine.CreateSingletonPool: IDBConnectionPool;
begin
  Result := TSingletonDBConnectionFactory.Create(FPool.GetConnection);
end;

function TAureliusOctopusEngine.FindDefinitionByKey(
  const Key: string): IProcessDefinition;
begin
  Result := CreateRepository(FPool).FindDefinitionByKey(Key);
end;

function TAureliusOctopusEngine.FindInstances: IInstanceQuery;
begin
  Result := CreateRuntime(FPool).CreateInstanceQuery;
end;

function TAureliusOctopusEngine.GetVariable(const InstanceId, VariableName: string): IVariable;
begin
  Result := CreateInstanceService(InstanceId).LoadVariable(VariableName);
end;

function TAureliusOctopusEngine.PublishDefinition(const Key, Process: string; const Name: string = ''): string;
begin
  ValidateDefinition(Process);
  Result := CreateRepository(FPool).PublishDefinition(Key, Process, Name);
end;

procedure TAureliusOctopusEngine.RunInstance(Process: TWorkflowProcess;
  Instance: IProcessInstanceData; Variables: IVariablesPersistence;
  Connection: IDBConnection);
var
  runner: TWorkflowRunner;
begin
  runner := TWorkflowRunner.Create(Process, Instance, Variables, Connection);
  try
    runner.DueDateIntervalMS := DueDateIntervalMS;
    runner.Execute;
  finally
    runner.Free;
  end;
end;

procedure TAureliusOctopusEngine.RunInstance(const InstanceId: string);
var
  Process: TWorkflowProcess;
  ProcessId: string;
  Instance: IProcessInstanceData;
  VariablesPersistence: IVariablesPersistence;
  Runtime: IOctopusInstanceService;
  SingletonPool: IDBConnectionPool;
begin
  SingletonPool := CreateSingletonPool;
  ProcessId := CreateRuntime(SingletonPool).GetInstanceProcessId(InstanceId);
  Process := CreateRepository(SingletonPool).GetDefinition(ProcessId);
  try
    Instance := TAureliusInstanceData.Create(SingletonPool, InstanceId);
    Runtime := TAureliusInstanceService.Create(SingletonPool, InstanceId);
    VariablesPersistence := TContextVariables.Create(Runtime);
    RunInstance(Process, Instance, VariablesPersistence, SingletonPool.GetConnection);
  finally
    Process.Free;
  end;
end;

procedure TAureliusOctopusEngine.RunPendingInstances;
var
  Runtime: IOctopusRuntime;
  Instance: IProcessInstance;
  Instances: TArray<IProcessInstance>;
begin
  Runtime := CreateRuntime(FPool);
  Instances := Runtime.GetPendingInstances;
  Runtime := nil;
  for Instance in Instances do
    RunInstance(Instance.Id)
end;

procedure TAureliusOctopusEngine.SetVariable(const InstanceId,
  VariableName: string; const Value: TValue);
var
  Instance: IProcessInstanceData;
begin
  Instance := TAureliusInstanceData.Create(FPool, InstanceId);
  Instance.Lock(FLockTimeoutMS);
  try
    CreateInstanceService(InstanceId).SaveVariable(VariableName, Value);
  finally
    Instance.Unlock;
  end;
end;

procedure TAureliusOctopusEngine.ValidateDefinition(const ProcessJson: string);
var
  Process: TWorkflowProcess;
  Validator: TWorkflowProcessValidator;
begin
  Process := TWorkflowDeserializer.ProcessFromJson(ProcessJson);
  try
    Validator := TWorkflowProcessValidator.Create;
    try
      Validator.Validate(Process);
      if Validator.Results.Count > 0 then
        raise EProcessValidationException.Create(Validator.Results);
    finally
      Validator.Free;
    end;
  finally
    Process.Free;
  end;
end;

{ TAureliusStorage }

constructor TAureliusStorage.Create(APool: IDBConnectionPool);
begin
  inherited Create;
  FPool := APool;
end;

function TAureliusStorage.GetPool: IDBConnectionPool;
begin
  Result := FPool;
end;

end.
