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
  Octopus.Json.Serializer,
  Octopus.Engine,
  Octopus.Engine.Aurelius,
  BusinessObjects in 'BusinessObjects.pas';

var
  Engine: IOctopusEngine;

function CreateHelloProcess: TWorkflowProcess;
begin
  {
   (start) --> <gateway> --- young ---> [hello] ----> (end)
                    |
                    +-----------------> [goodbye] --> (end)
  }
  Result := TProcessBuilder.CreateProcess
    .Variable('age')
    .StartEvent
    .ExclusiveGateway
      .Condition(TYoungPersonCondition.Create)
      .Activity(TWriteLnActivity.Create('Hello, world.'))
      .EndEvent
    .GotoLastGateway
      .Activity(TWriteLnActivity.Create('Goodbye, world.'))
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

var
  Pool: IDBConnectionPool;
  ProcessId: string;
  HelloProcess: TWorkflowProcess;
begin
  try
    Pool := TSingletonDBConnectionFactory.Create(TSQLiteNativeConnectionAdapter.Create('D:\trash\octopus.db'));
    TDatabaseManager.Update(Pool.GetConnection, TMappingExplorer.Get(OctopusModel));
    Engine := TAureliusOctopusEngine.Create(Pool);
    HelloProcess := CreateHelloProcess;
    try
      ProcessId := Engine.PublishDefinition('HelloProcess',
        TWorkflowSerializer.ProcessToJson(HelloProcess));
    finally
      HelloProcess.Free;
    end;
    AskForAges(ProcessId);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
