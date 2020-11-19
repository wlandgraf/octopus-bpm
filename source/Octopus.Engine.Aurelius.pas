unit Octopus.Engine.Aurelius;

interface

uses
  Aurelius.Drivers.Interfaces,
  Octopus.Persistence.Common,
  Octopus.Persistence.Aurelius,
  Octopus.Process,
  Octopus.Engine,
  Octopus.Engine.Runner;

type
  TAureliusOctopusEngine = class(TInterfacedObject, IOctopusEngine)
  strict private
    FPool: IDBConnectionPool;
    FProcessFactory: IOctopusProcessFactory;
    function CreateRepository: IOctopusRepository;
    function CreateRuntime: IOctopusRuntime;
    procedure RunInstance(Process: TWorkflowProcess; Instance: IProcessInstanceData); overload;
  public
    constructor Create(APool: IDBConnectionPool); overload;
    constructor Create(APool: IDBConnectionPool; AProcessFactory: IOctopusProcessFactory); overload;
    property Pool: IDBConnectionPool read FPool;
  public
    { IOctopusEngine methods }
    function PublishDefinition(const Name: string; const Process: string = ''): string;
    function CreateInstance(const ProcessId: string): string;
    procedure RunInstance(const InstanceId: string); overload;
  end;

implementation

{ TAureliusOctopusEngine }

constructor TAureliusOctopusEngine.Create(APool: IDBConnectionPool);
begin
  Create(APool, nil);
end;

constructor TAureliusOctopusEngine.Create(APool: IDBConnectionPool;
  AProcessFactory: IOctopusProcessFactory);
begin
  inherited Create;
  FPool := APool;
  FProcessFactory := AProcessFactory;
end;

function TAureliusOctopusEngine.CreateInstance(const ProcessId: string): string;
var
  Instance: IProcessInstanceData;
  Process: TWorkflowProcess;
begin
  Result := CreateRuntime.CreateInstance(ProcessId);
  Process := CreateRepository.GetDefinition(ProcessId);
  Instance := TAureliusInstanceData.Create(Pool, Result);
  Process.InitInstance(Instance);
end;

function TAureliusOctopusEngine.CreateRepository: IOctopusRepository;
begin
  Result := TAureliusRepository.Create(Pool, FProcessFactory);
end;

function TAureliusOctopusEngine.CreateRuntime: IOctopusRuntime;
begin
  Result := TAureliusRuntime.Create(Pool);
end;

function TAureliusOctopusEngine.PublishDefinition(const Name: string; const Process: string = ''): string;
begin
  Result := CreateRepository.PublishDefinition(Name, Process);
end;

procedure TAureliusOctopusEngine.RunInstance(Process: TWorkflowProcess;
  Instance: IProcessInstanceData);
var
  runner: TWorkflowRunner;
begin
  runner := TWorkflowRunner.Create(Process, Instance);
  try
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
begin
  ProcessId := CreateRuntime.GetInstanceProcessId(InstanceId);
  Process := CreateRepository.GetDefinition(ProcessId);
  Instance := TAureliusInstanceData.Create(Pool, InstanceId);
  RunInstance(Process, Instance);
end;

end.
