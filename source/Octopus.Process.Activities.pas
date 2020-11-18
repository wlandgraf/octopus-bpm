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

  TActivityExecutionContext = class
  private
    FToken: TToken;
    FDone: boolean;
    FInstance: IProcessInstanceData;
    FError: boolean;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken);
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; Value: TValue);
    function GetLocalVariable(const Name: string): TValue;
    procedure SetLocalVariable(const Name: string; Value: TValue);
    property Token: TToken read FToken;
    property Done: boolean read FDone write FDone;
    property Error: boolean read FError write FError;
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

implementation

uses
  Octopus.Resources;

{ TAnonymousActivity }

constructor TAnonymousActivity.Create(Proc: TActivityExecuteProc);
begin
  inherited Create;
  FExecuteProc := Proc;
end;

procedure TAnonymousActivity.ExecuteInstance(Context: TActivityExecutionContext);
begin
  FExecuteProc(Context);
end;

{ TActivity }

procedure TActivity.Execute(Context: TExecutionContext);
var
  token: TToken;
begin
  token := Context.GetIncomingToken;
  while token <> nil do
  begin
    ExecuteActivityInstance(token, Context);

    if Context.Error then // TODO: error handling
      exit;

    token := Context.GetIncomingToken;
  end;
end;

procedure TActivity.ExecuteActivityInstance(Token: TToken; Context: TExecutionContext);
var
  aec: TActivityExecutionContext;
begin
  aec := TActivityExecutionContext.Create(Context, Token);
  try
    ExecuteInstance(aec);

    if aec.Error then // TODO: error handling
    begin
      Context.Error := aec.Error;
      exit;
    end;

    if aec.Done then
    begin
      Context.Instance.RemoveToken(Token);

      ScanTransitions(
        procedure(Transition: TTransition)
        begin
          if Transition.Evaluate(Context) then
            Context.Instance.AddToken(Transition);
        end);
    end
    else
      Context.Instance.DeactivateToken(Token);
  finally
    aec.Free;
  end;
end;

{ TActivityExecutionContext }

constructor TActivityExecutionContext.Create(AContext: TExecutionContext; AToken: TToken);
begin
  FInstance := AContext.Instance;
  FToken := AToken;
  FDone := true;
  FError := false;
end;

function TActivityExecutionContext.GetLocalVariable(const Name: string): TValue;
begin
  result := FInstance.GetLocalVariable(Token, Name);
end;

function TActivityExecutionContext.GetVariable(const Name: string): TValue;
begin
  result := FInstance.GetVariable(Name)
end;

procedure TActivityExecutionContext.SetLocalVariable(const Name: string; Value: TValue);
begin
  FInstance.SetLocalVariable(Token, Name, Value);
end;

procedure TActivityExecutionContext.SetVariable(const Name: string; Value: TValue);
begin
  FInstance.SetVariable(Name, Value);
end;

end.

