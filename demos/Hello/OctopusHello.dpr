program OctopusHello;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Process.Builder,
  Octopus.Persistence.Memory,
  Octopus.Engine.Runner;

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

procedure LaunchInstance(Process: TWorkflowProcess; Age: Integer);
var
  Instance: IProcessInstanceData;
  Runner: TWorkflowRunner;
begin
  Instance := TMemoryInstanceData.Create;
  Process.InitInstance(Instance);
  Instance.SetVariable('age', Age);
  Runner := TWorkflowRunner.Create(Process, Instance);
  try
    Runner.Execute;
  finally
    Runner.Free;
  end;
end;

procedure AskForAges(Process: TWorkflowProcess);
var
  Age: Integer;
begin
  repeat
    Write('Please type your age: ');
    ReadLn(Age);
    if Age <= 0 then Exit;

    LaunchInstance(Process, Age);
  until False;
end;

procedure Run;
var
  Process: TWorkflowProcess;
begin
  Process := CreateHelloProcess;
  try
    AskForAges(Process);
  finally
    Process.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
