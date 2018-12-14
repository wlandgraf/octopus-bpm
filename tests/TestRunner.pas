unit TestRunner;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  OctopusTestCase,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Engine.Runner;

type
  [TestFixture]
  TTestRunner = class(TOctopusTestCase)
  private
    procedure LogVariable(AName: string);
  public
    [Test] procedure RunEmpty;
    [Test] procedure RunError;
    [Test] procedure RunStop;
    [Test] procedure RunPersist;
  end;

implementation

uses
  OctopusTestUtils,
  MemoryInstanceData;

{ TTestRunner }

procedure TTestRunner.LogVariable(AName: string);
begin
  TDUnitX.CurrentRunner.Log(TLogLevel.Information, Format('%s = %s', [AName, Process.GetVariable(AName).DefaultValue.ToString]));
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
    Assert.AreEqual(1, instance.CountTokens); // running
    LogVariable('done');

    // not done, persist
    RunInstance(instance);
    Assert.AreEqual(1, instance.CountTokens); // running
    LogVariable('done');

    // done, finish
    instance.SetVariable('done', true);
    RunInstance(instance);
    Assert.AreEqual(0, instance.CountTokens); // finished
  finally
    instance.Free;
  end;
end;

procedure TTestRunner.RunStop;
begin
  { (start) -> [test] -> (end) }
  Builder
    .StartEvent
    .Activity(TTestUtils.PersistedActivity)
    .EndEvent;

  RunProcess(TRunnerStatus.Processed, 1);
end;

end.

