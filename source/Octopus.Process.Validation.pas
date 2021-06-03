unit Octopus.Process.Validation;

interface

uses
  Generics.Collections,
  Octopus.Process,
  Aurelius.Validation,
  Aurelius.Validation.Interfaces;

type
  IProcessValidationResult = interface(IValidationResult)
  ['{CD8A58DA-6590-4F30-B986-DA8620FACC58}']
    function GetElement: TFlowElement;
    property Element: TFlowElement read GetElement;
  end;

  TProcessValidationResult = class(TInterfacedObject, IProcessValidationResult, IValidationResult)
  strict private
    FInnerResult: IValidationResult;
    FElement: TFlowElement;
  strict private
    { IValidationResult }
    function GetSucceeded: Boolean;
    function GetErrors: TList<IValidationError>;
  strict private
    { IProcessValidationResult }
    function GetElement: TFlowElement;
  public
    constructor Create(AResult: IValidationResult; AElement: TFlowElement);
  end;

  IProcessValidationContext = interface(IValidationContext)
  ['{1B5797FD-66C6-4591-BAE1-A5C9C2768C57}']
    function GetProcess: TWorkflowProcess;
    property Process: TWorkflowProcess read GetProcess;
  end;

  TProcessValidationContext = class(TInterfacedObject, IProcessValidationContext, IValidationContext)
  strict private
    FProcess: TWorkflowProcess;
    function GetProcess: TWorkflowProcess;
    function GetDisplayName: string;
  public
    constructor Create(AProcess: TWorkflowProcess);
    property Process: TWorkflowProcess read GetProcess;
    property DisplayName: string read GetDisplayName;
  end;

  TWorkflowProcessValidator = class
  strict private
    FProcess: TWorkflowProcess;
//    FNodeValidators: TList<IValidator>;
    FResults: TList<IValidationResult>;
    FValidators: TList<IValidator>;
    procedure AddBuiltinValidators;
  protected
    property Process: TWorkflowProcess read FProcess;
//    property NodeValidators: TList<IValidator> read FNodeValidators;
    property Validators: TList<IValidator> read FValidators;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validate(AProcess: TWorkflowProcess);
    property Results: TList<IValidationResult> read FResults;
  end;

  TProcessValidator = class(TValidator<TWorkflowProcess>)
  end;

  TStartNodeValidator = class(TProcessValidator)
    function DoValidate(const Process: TWorkflowProcess; Context: IValidationContext): IValidationResult; override;
  end;

implementation

uses
  Octopus.Resources;

{ TProcessValidationResult }

constructor TProcessValidationResult.Create(AResult: IValidationResult; AElement: TFlowElement);
begin
  inherited Create;
  FInnerResult := AResult;
  FElement := AElement;
end;

function TProcessValidationResult.GetElement: TFlowElement;
begin
  Result := FElement;
end;

function TProcessValidationResult.GetErrors: TList<IValidationError>;
begin
  Result := FInnerResult.GetErrors;
end;

function TProcessValidationResult.GetSucceeded: Boolean;
begin
  Result := FInnerResult.GetSucceeded;
end;

{ TProcessValidationContext }

constructor TProcessValidationContext.Create(AProcess: TWorkflowProcess);
begin
  inherited Create;
  FProcess := AProcess;
end;

function TProcessValidationContext.GetDisplayName: string;
begin
  Result := '';
end;

function TProcessValidationContext.GetProcess: TWorkflowProcess;
begin
  Result := FProcess;
end;

{ TProcessValidator }

procedure TWorkflowProcessValidator.AddBuiltinValidators;
begin
  Validators.Add(TStartNodeValidator.Create);
end;

constructor TWorkflowProcessValidator.Create;
begin
  inherited Create;
  FValidators := TList<IValidator>.Create;
  FResults := TList<IValidationResult>.Create;
  AddBuiltinValidators;
end;

destructor TWorkflowProcessValidator.Destroy;
begin
  FValidators.Free;
  FResults.Free;
  inherited;
end;

procedure TWorkflowProcessValidator.Validate(AProcess: TWorkflowProcess);

  procedure ProcessResult(ValidationResult: IValidationResult; Element: TFlowElement);
  begin
    if (ValidationResult <> nil) and not ValidationResult.Succeeded then
      Results.Add(TProcessValidationResult.Create(ValidationResult, Element));
  end;

var
  Validator: IValidator;
  Context: IProcessValidationContext;
  Node: TFlowNode;
  Transition: TTransition;
begin
  FResults.Clear;
  FProcess := AProcess;

  Process.Prepare;
  Context := TProcessValidationContext.Create(Process);

  for Node in Process.Nodes do
    ProcessResult(Node.Validate(Context), Node);

  for Transition in Process.Transitions do
    ProcessResult(Transition.Validate(Context), Transition);

  for Validator in Validators do
    ProcessResult(Validator.Validate(Process, Context), nil);
end;

{ TStartNodeValidator }

function TStartNodeValidator.DoValidate(const Process: TWorkflowProcess;
  Context: IValidationContext): IValidationResult;
var
  start, node: TFlowNode;
begin
  Result := TValidationResult.Create;
  start := nil;
  for node in Process.Nodes do
  begin
    if node.IsStart then
    begin
      if Assigned(start) then
        Exit(TValidationResult.Failed(SErrorDuplicateStartEvent))
      else
        start := node;
    end;
  end;
  if not Assigned(start) then
    Result := TValidationResult.Failed(SErrorNoStartEvent);
end;

end.
