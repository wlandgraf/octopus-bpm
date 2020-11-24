program OctopusHello;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Generics.Collections,
  System.SysUtils,
  Aurelius.Sql.SQLite,
  Aurelius.Schema.SQLite,
  Aurelius.Engine.DatabaseManager,
  Aurelius.Mapping.Explorer,
  Aurelius.Drivers.SQLite,
  Aurelius.Drivers.Interfaces,
  Aurelius.Drivers.Base,
  Octopus.Entities,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Process.Builder,
  Octopus.Persistence.Common,
  Octopus.Engine,
  Octopus.Engine.Aurelius;

var
  Engine: IOctopusEngine;

function CreateHelloProcess: TWorkflowProcess;
begin
  Result := TProcessBuilder.CreateProcess
    .Variable('age')
    .StartEvent
    .ExclusiveGateway
      .Condition(
        function(Context: TExecutionContext): boolean
        begin
          result := Context.Instance.GetVariable('age').AsInteger <= 70;
        end
      )
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          WriteLn('Hello, world.');
        end))
      .EndEvent
    .GotoLastGateway
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          WriteLn('Goodbye, world.');
        end))
      .EndEvent
    .Done;
end;

procedure LaunchInstance(const ProcessId: string; Age: Integer);
var
  InstanceId: string;
  Variables: TList<TVariable>;
begin
  Variables := TObjectList<TVariable>.Create;
  try
    Variables.Add(TVariable.Create('age', Age));
    InstanceId := Engine.CreateInstance(ProcessId, Variables);
  finally
    Variables.Free;
  end;
  Engine.RunInstance(InstanceId);
end;

procedure AskForAges(const ProcessId: string);
var
  Age: Integer;
begin
  repeat
    Write('Please type your age: ');
    ReadLn(Age);
    if Age <= 0 then Exit;

    LaunchInstance(ProcessId, Age);
  until False;
end;

type
  TProcessFactory = class(TInterfacedObject, IOctopusProcessFactory)
  strict private
    FProcess: TWorkflowProcess;
  public
    constructor Create(Process: TWorkflowProcess);
    destructor Destroy; override;
    procedure GetProcessDefinition(const ProcessId: string; var Process: TWorkflowProcess);
  end;

{ TProcessFactory }

constructor TProcessFactory.Create(Process: TWorkflowProcess);
begin
  inherited Create;
  FProcess := Process;
end;

destructor TProcessFactory.Destroy;
begin
  FProcess.Free;
  inherited;
end;

procedure TProcessFactory.GetProcessDefinition(const ProcessId: string;
  var Process: TWorkflowProcess);
begin
  Process := FProcess;
end;

var
  Pool: IDBConnectionPool;
  ProcessId: string;

begin
  try
    Pool := TSingletonDBConnectionFactory.Create(TSQLiteNativeConnectionAdapter.Create(':memory:'));
    TDatabaseManager.Update(Pool.GetConnection, TMappingExplorer.Get(OctopusModel));
    Engine := TAureliusOctopusEngine.Create(Pool, TProcessFactory.Create(CreateHelloProcess));
    ProcessId := Engine.PublishDefinition('HelloProcess');
    AskForAges(ProcessId);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
