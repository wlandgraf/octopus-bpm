unit Octopus.Process.Events;

interface

uses
  Octopus.Process;

type
  TEvent = class(TFlowNode)
  public
    procedure Execute(Context: TExecutionContext); override;
  end;

  TStartEvent = class (TEvent)
  public
    function IsStart: boolean; override;
    function Validate(Context: IValidationContext): IValidationResult; override;
  end;

  TEndEvent = class(TEvent)
  public
    function Validate(Context: IValidationContext): IValidationResult; override;
  end;

implementation

uses
  Octopus.Resources;

{ TEndEvent }

function TEndEvent.Validate(Context: IValidationContext): IValidationResult;
begin
  Result := TValidationResult.Create;
  if IncomingTransitions.Count = 0 then
    Result.Errors.Add(TValidationError.Create(SErrorNoIncomingTransition));
  if OutgoingTransitions.Count > 0 then
    Result.Errors.Add(TValidationError.Create(SErrorEndEventOutgoing));
end;

{ TStartEvent }

function TStartEvent.IsStart: boolean;
begin
  result := true;
end;

function TStartEvent.Validate(Context: IValidationContext): IValidationResult;
begin
  Result := TValidationResult.Create;
  if IncomingTransitions.Count > 0 then
    Result.Errors.Add(TValidationError.Create(SErrorStartEventIncoming));
  if OutgoingTransitions.Count = 0 then
    Result.Errors.Add(TValidationError.Create(SErrorNoOutgoingTransition));
end;

{ TEvent }

procedure TEvent.Execute(Context: TExecutionContext);
begin
  FlowTokens(Context);
end;

end.

