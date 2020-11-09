unit OctopusTests.Cases.Validator;

interface

uses
  OctopusTests.TestCase,
  Octopus.Validator;

type
  TTestValidator = class(TOctopusTestCase)
  private
    FValidator: TWorkflowValidator;
    procedure CheckValid(IsValid: boolean);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure EmptyProcess;
    procedure EndEvent;
    procedure StartEvent;
    procedure EventTransitions;
    procedure StartEnd;
  end;

implementation

uses
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Process.Events;

{ TTestValidator }

procedure TTestValidator.CheckValid(IsValid: boolean);
var
  res: TValidationResult;
begin
  CheckEquals(IsValid, FValidator.Check(Process));

  for res in FValidator.Results do
  begin
    if res.Error then
      Status('Error: ' + res.Message)
    else
      Status('Warning: ' + res.Message);
  end;
end;

procedure TTestValidator.EmptyProcess;
begin
  CheckValid(false);
end;

procedure TTestValidator.EndEvent;
begin
  Process.Nodes.Add(TEndEvent.Create);
  CheckValid(false);
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
  CheckValid(false); // no transitions

  transition := TTransition.Create;
  Process.Transitions.Add(transition);
  transition.Source := startEvent;
  transition.Target := endEvent;
  CheckValid(true); // start -> end transition

  transition := TTransition.Create;
  Process.Transitions.Add(transition);
  CheckValid(false); // untied transition

  transition.Source := endEvent;
  transition.Target := startEvent;
  CheckValid(false); // start -> end -> start
end;

procedure TTestValidator.Setup;
begin
  inherited;
  FValidator := TWorkflowValidator.Create;
end;

procedure TTestValidator.StartEnd;
begin
  Builder.StartEvent.EndEvent;
  CheckValid(true);
end;

procedure TTestValidator.StartEvent;
begin
  Process.Nodes.Add(TStartEvent.Create);
  CheckValid(false);
end;

procedure TTestValidator.TearDown;
begin
  FValidator.Free;
  inherited;
end;

initialization
  RegisterOctopusTest(TTestValidator);
end.

