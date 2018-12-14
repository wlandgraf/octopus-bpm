unit Octopus.Validator;

interface

uses
  Generics.Collections,
  Octopus.Process;

type
  TWorkflowValidator = class
  private
    FContext: TValidationContext;
    function GetResults: TList<TValidationResult>;
  public
    constructor Create;
    destructor Destroy; override;
    function Check(Process: TWorkflowProcess): boolean;
    function HasErrors: boolean;
    property Results: TList<TValidationResult> read GetResults;
  end;

implementation

uses
  Octopus.Resources;

{ TWorkflowValidator }

function TWorkflowValidator.Check(Process: TWorkflowProcess): boolean;
var
  start, node: TFlowNode;
  transition: TTransition;
begin
  FContext.Results.Clear;
  start := nil;

  for node in Process.Nodes do
    node.EnumTransitions(Process);

  for node in Process.Nodes do
  begin
    if node.IsStart then
    begin
      if Assigned(start) then
        FContext.AddError(node, SErrorDuplicateStartEvent)
      else
        start := node;
    end;

    node.Validate(FContext);
  end;

  for transition in Process.Transitions do
    transition.Validate(FContext);

  if not Assigned(start) then
    FContext.AddError(nil, SErrorNoStartEvent);

  result := not HasErrors;
end;

constructor TWorkflowValidator.Create;
begin
  FContext := TValidationContext.Create;
end;

destructor TWorkflowValidator.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TWorkflowValidator.GetResults: TList<TValidationResult>;
begin
  result := FContext.Results;
end;

function TWorkflowValidator.HasErrors: boolean;
var
  res: TValidationResult;
begin
  for res in Results do
    if res.Error then
      exit(true);
  result := false;
end;

end.

