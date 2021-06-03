unit Octopus.Process.Validation;

interface

uses
  Generics.Collections, Rtti, SysUtils,
  Octopus.Process,
  Octopus.Exceptions,
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
    FResults: TList<IProcessValidationResult>;
    FValidators: TList<IValidator>;
    procedure AddBuiltinValidators;
  protected
    property Process: TWorkflowProcess read FProcess;
    property Validators: TList<IValidator> read FValidators;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validate(AProcess: TWorkflowProcess);
    property Results: TList<IProcessValidationResult> read FResults;
  end;

  TSelectiveValidator<T> = class(TValidator)
  public
    function Validate(const Value: TValue; Context: IValidationContext): IValidationResult; override;
    function DoValidate(const Value: T; Context: IValidationContext): IValidationResult; virtual; abstract;
  end;

  TProcessValidator = class(TSelectiveValidator<TWorkflowProcess>)
  end;

  TStartNodeValidator = class(TProcessValidator)
    function DoValidate(const Process: TWorkflowProcess; Context: IValidationContext): IValidationResult; override;
  end;

  TIdRequiredValidator = class(TSelectiveValidator<TFlowElement>)
  public
    function DoValidate(const Value: TFlowElement; Context: IValidationContext): IValidationResult; override;
  end;

  EProcessValidationException = class(EOctopusException)
  strict private
    FResults: TList<IProcessValidationResult>;
  public
    constructor Create(AResults: TList<IProcessValidationResult>);
    destructor Destroy; override;
    property Results: TList<IProcessValidationResult> read FResults;
  end;

implementation

uses
  Octopus.Resources;

{ EProcessValidationException }

constructor EProcessValidationException.Create(AResults: TList<IProcessValidationResult>);
var
  Msg: string;
begin
  FResults := TList<IProcessValidationResult>.Create;
  FResults.AddRange(AResults);
  Msg := SErrorProcessValidationFailed;
  if (FResults.Count = 1) and (FResults[0].Errors.Count = 1) then
    Msg := Msg + ': ' + FResults[0].Errors[0].ErrorMessage;
  inherited Create(Msg);
end;

destructor EProcessValidationException.Destroy;
begin
  FResults.Free;
  inherited;
end;

{ TElementValidator<T> }

function TSelectiveValidator<T>.Validate(const Value: TValue; Context: IValidationContext): IValidationResult;
begin
  if Value.IsType<T> then
    Result := DoValidate(Value.AsType<T>, Context)
  else
    Result := TValidationResult.Success;
end;

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
  Validators.Add(TIdRequiredValidator.Create);
end;

constructor TWorkflowProcessValidator.Create;
begin
  inherited Create;
  FValidators := TList<IValidator>.Create;
  FResults := TList<IProcessValidationResult>.Create;
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
  begin
    ProcessResult(Node.Validate(Context), Node);
    for Validator in Validators do
      ProcessResult(Validator.Validate(Node, Context), Node);
  end;


  for Transition in Process.Transitions do
  begin
    ProcessResult(Transition.Validate(Context), Transition);
    for Validator in Validators do
      ProcessResult(Validator.Validate(Transition, Context), Transition);
  end;

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


{ TNameRequiredValidator }

function TIdRequiredValidator.DoValidate(const Value: TFlowElement; Context: IValidationContext): IValidationResult;
begin
  if Trim(Value.Id) = '' then
    Result := TValidationResult.Failed(SErrorElementHasNoId);

end;

end.
