unit Octopus.Process.Activities;

interface

uses
  System.Rtti,
  Generics.Collections,
  Octopus.Process;

type
  TActivity = class;
  TActivityExecutionContext = class;

  TActivity = class abstract(TFlowNode)
  private
    procedure ExecuteActivityInstance(Token: TToken; Context: TExecutionContext);
  public
    procedure Execute(Context: TExecutionContext); override;
    procedure ExecuteInstance(Context: TActivityExecutionContext); virtual; abstract;
  end;

  TActivityExecutionContext = class(TTokenExecutionContext)
  private
    FDone: boolean;
    function GetNode: TFlowNode;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken);
    property Done: boolean read FDone write FDone;
    property Node: TFlowNode read GetNode;
  end;

  TActivityClass = class of TActivity;

  TActivityExecuteProc = reference to procedure(Context: TActivityExecutionContext);

  TAnonymousActivity = class(TActivity)
  private
    FExecuteProc: TActivityExecuteProc;
  public
    constructor Create(Proc: TActivityExecuteProc); reintroduce;
    procedure ExecuteInstance(Context: TActivityExecutionContext); override;
  end;

  TActivityExecutor = class
  strict private
    FContext: TActivityExecutionContext;
  public
    constructor Create(Context: TActivityExecutionContext); virtual;
    procedure Execute; virtual; abstract;
    property Context: TActivityExecutionContext read FContext;
  end;

implementation

uses
  Octopus.Exceptions,
  Octopus.Resources;

{ TAnonymousActivity }

constructor TAnonymousActivity.Create(Proc: TActivityExecuteProc);
begin
  inherited Create;
  FExecuteProc := Proc;
end;

procedure TAnonymousActivity.ExecuteInstance(Context: TActivityExecutionContext);
begin
  if Assigned(FExecuteProc) then
    FExecuteProc(Context);
end;

{ TActivity }

procedure TActivity.Execute(Context: TExecutionContext);
var
  token: TToken;
  tokens: TList<TToken>;
begin
  tokens := Context.GetTokens(TTokens.Active(Self.Id));
  try
    for token in tokens do
      ExecuteActivityInstance(token, Context);
  finally
    tokens.Free;
  end;
end;

procedure TActivity.ExecuteActivityInstance(Token: TToken; Context: TExecutionContext);
var
  aec: TActivityExecutionContext;
begin
  aec := TActivityExecutionContext.Create(Context, Token);
  try
    ExecuteInstance(aec);

    if aec.Done then
    begin
      Context.RemoveToken(Token);

      ScanTransitions(Context, Token,
        procedure(Ctxt: TTransitionExecutionContext)
        begin
          if Ctxt.Transition.Evaluate(Ctxt) then
            Context.AddToken(Ctxt.Transition, Token);
        end);
    end
    else
      Context.DeactivateToken(Token);
  finally
    aec.Free;
  end;
end;

{ TActivityExecutionContext }

constructor TActivityExecutionContext.Create(AContext: TExecutionContext; AToken: TToken);
begin
  inherited Create(AContext, AToken);
  FDone := true;
end;

function TActivityExecutionContext.GetNode: TFlowNode;
begin
  Result := Context.Node;
end;

{ TActivityExecutor }

constructor TActivityExecutor.Create(Context: TActivityExecutionContext);
begin
  inherited Create;
  FContext := Context;
end;

end.

