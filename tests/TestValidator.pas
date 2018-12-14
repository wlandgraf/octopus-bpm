unit TestValidator;

interface

uses
  DUnitX.TestFramework,
  OctopusTestCase,
  Octopus.Validator;

type
  [TestFixture]
  TTestValidator = class(TOctopusTestCase)
  private
    FValidator: TWorkflowValidator;
    procedure Check(IsValid: boolean);
  public
    [Setup]
    procedure Setup; override;
    [TearDown]
    procedure TearDown; override;
    [Test] procedure EmptyProcess;
    [Test] procedure EndEvent;
    [Test] procedure StartEvent;
    [Test] procedure EventTransitions;
    [Test] procedure StartEnd;
  end;

implementation

uses
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Process.Events;

{ TTestValidator }

procedure TTestValidator.Check(IsValid: boolean);
var
  res: TValidationResult;
begin
  Assert.AreEqual(IsValid, FValidator.Check(Process));

  for res in FValidator.Results do
  begin
    if res.Error then
      TDUnitX.CurrentRunner.Log(TLogLevel.Error, res.Message)
    else
      TDUnitX.CurrentRunner.Log(TLogLevel.Warning, res.Message);
  end;
end;

procedure TTestValidator.EmptyProcess;
begin
  Check(false);
end;

procedure TTestValidator.EndEvent;
begin
  Process.Nodes.Add(TEndEvent.Create);
  Check(false);
end;

procedure TTestValidator.EventTransitions;
var
  startEvent, endEvent: TEvent;
  transition: TTransition;
begin
  startEvent := TStartEvent.Create;
  Process.Nodes.Add(startEvent);
  endEvent :=  TEndEvent.Create;
  Process.Nodes.Add(endEvent);
  Check(false); // no transitions

  transition := TTransition.Create;
  Process.Transitions.Add(transition);
  transition.Source := startEvent;
  transition.Target := endEvent;
  Check(true); // start -> end transition

  transition := TTransition.Create;
  Process.Transitions.Add(transition);
  Check(false); // untied transition

  transition.Source := endEvent;
  transition.Target := startEvent;
  Check(false); // start -> end -> start
end;

procedure TTestValidator.Setup;
begin
  inherited;
  FValidator := TWorkflowValidator.Create;
end;

procedure TTestValidator.StartEnd;
begin
  Builder.StartEvent.EndEvent;
  Check(true);
end;

procedure TTestValidator.StartEvent;
begin
  Process.Nodes.Add(TStartEvent.Create);
  Check(false);
end;

procedure TTestValidator.TearDown;
begin
  FValidator.Free;
  inherited;
end;

end.

