unit Octopus.Process.Validation;

interface

uses
  Generics.Collections,
  Octopus.Process,
  Aurelius.Validation.Interfaces;

type
//  IProcessValidationResult = interface(IValidationResult)
//  ['{CD8A58DA-6590-4F30-B986-DA8620FACC58}']
//  end;
//
//  TProcessValidationResult = class(TInterfacedObject, IProcessValidationResult, IValidationResult)
//  strict private
//    FInnerResult: IValidationResult;
//  strict private
//    { IValidationResult }
//    function GetSucceeded: Boolean;
//    function GetErrors: TList<IValidationError>;
//  public
//    constructor Create(AResult: IValidationResult);
//  end;

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

  TProcessValidator = class
  strict private
    FProcess: TWorkflowProcess;
    FNodeValidators: TList<IValidator>;
    FResults: TList<IValidationResult>;
  protected
    property Process: TWorkflowProcess read FProcess;
    property NodeValidators: TList<IValidator> read FNodeValidators;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Validate(AProcess: TWorkflowProcess);
    property Results: TList<IValidationResult> read FResults;
  end;

implementation

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

constructor TProcessValidator.Create;
begin
  inherited Create;
  FNodeValidators := TList<IValidator>.Create;
  FResults := TList<IValidationResult>.Create;
end;

destructor TProcessValidator.Destroy;
begin
  FNodeValidators.Free;
  FResults.Free;
  inherited;
end;

procedure TProcessValidator.Validate(AProcess: TWorkflowProcess);

  procedure ProcessResult(ValidationResult: IValidationResult);
  begin
    if (ValidationResult <> nil) and not ValidationResult.Succeeded then
      FResults.Add(ValidationResult);
  end;

var
  Validator: IValidator;
  Context: IProcessValidationContext;
  Node: TFlowNode;
begin
  FResults.Clear;
  FProcess := AProcess;
  Context := TProcessValidationContext.Create(Process);

  for Node in Process.Nodes do
    for Validator in NodeValidators do
      ProcessResult(Validator.Validate(Node, Context));
end;

end.
