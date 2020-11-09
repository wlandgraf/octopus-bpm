unit OctopusTests.Cases.Runner;

interface

uses
  System.SysUtils,
  OctopusTests.TestCase,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Engine.Runner;

type
  TTestRunner = class(TOctopusTestCase)
  private
    procedure LogVariable(AName: string);
  published
    procedure RunEmpty;
    procedure RunError;
    procedure RunStop;
    procedure RunPersist;
  end;

implementation

uses
  MemoryInstanceData;

{ TTestRunner }

procedure TTestRunner.LogVariable(AName: string);
begin
//  Status(Format('%s = %s', [AName, Process.GetVariable(AName).DefaultValue.ToString]));
end;

procedure TTestRunner.RunEmpty;
begin
  { (start) --> (end) }
  Builder.StartEvent.EndEvent;
  RunProcess(TRunnerStatus.Processed, 0);
end;

procedure TTestRunner.RunError;
begin
  { (start) --> [error] --> (end) }
  Builder
    .StartEvent
    .Activity(TAnonymousActivity.Create(
      procedure(Context: TActivityExecutionContext)
      begin
        Context.Error := true;
      end
    ))
    .EndEvent;

  RunProcess(TRunnerStatus.Error);
end;

procedure TTestRunner.RunPersist;
var
  instance: TMemoryInstanceData;
begin
  { (start) --> [wait until done] --> (end) }
  Builder
    .Variable('done', false)
    .StartEvent
    .Activity(TAnonymousActivity.Create(
      procedure(Context: TActivityExecutionContext)
      begin
        Context.Done := Context.GetVariable('done').AsBoolean;
      end)
    )
    .EndEvent;

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);

    // not done, persist
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    LogVariable('done');

    // not done, persist
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    LogVariable('done');

    // done, finish
    instance.SetVariable('done', true);
    RunInstance(instance);
    CheckEquals(0, instance.CountTokens); // finished
  finally
    instance.Free;
  end;
end;

procedure TTestRunner.RunStop;
begin
  { (start) -> [test] -> (end) }
  Builder
    .StartEvent
    .Activity(TAnonymousActivity.Create(
      procedure(Context: TActivityExecutionContext)
      begin
        Context.Done := false;
      end
    ))
    .EndEvent;

  RunProcess(TRunnerStatus.Processed, 1);
end;

initialization
  RegisterOctopusTest(TTestRunner);
end.

