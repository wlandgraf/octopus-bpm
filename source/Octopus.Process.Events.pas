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
    procedure Validate(Context: TValidationContext); override;
  end;

  TEndEvent = class(TEvent)
  public
    procedure Validate(Context: TValidationContext); override;
  end;

implementation

uses
  Octopus.Resources;

{ TEndEvent }

procedure TEndEvent.Validate(Context: TValidationContext);
begin
  if IncomingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoIncomingTransition);
  if OutgoingTransitions.Count > 0 then
    Context.AddError(Self, SErrorEndEventOutgoing);
end;

{ TStartEvent }

function TStartEvent.IsStart: boolean;
begin
  result := true;
end;

procedure TStartEvent.Validate(Context: TValidationContext);
begin
  if IncomingTransitions.Count > 0 then
    Context.AddError(Self, SErrorStartEventIncoming);
  if OutgoingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoOutgoingTransition);
end;

{ TEvent }

procedure TEvent.Execute(Context: TExecutionContext);
begin
  ExecuteAllTokens(Context, true);
end;

end.

