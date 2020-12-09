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
    FContext: TExecutionContext;
    function FindToken(const Id: string): TToken;
    function GetNode: TFlowNode;
    function FindVariable(const Name: string): IVariable;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken);
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; Value: TValue);
    function GetLocalVariable(const Name: string): TValue;
    procedure SetLocalVariable(const Name: string; Value: TValue);
    property Token: TToken read FToken;
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
      Context.Instance.RemoveToken(Token);

      ScanTransitions(
        procedure(Transition: TTransition)
        begin
          if Transition.Evaluate(Context) then
            Context.Instance.AddToken(Transition, Token.Id);
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
  FContext := AContext;
  FInstance := AContext.Instance;
  FToken := AToken;
  FDone := true;
end;

function TActivityExecutionContext.FindToken(const Id: string): TToken;
begin
  Result := nil;
end;

function TActivityExecutionContext.FindVariable(const Name: string): IVariable;
var
  TargetToken: TToken;
begin
  Result := FInstance.GetVariable(Name);
  Exit;


  // Optimize this later!
  TargetToken := Self.Token;
  repeat
    Result := FInstance.GetTokenVariable(TargetToken, Name);
    if Result <> nil then
      Exit;
    TargetToken := FindToken(TargetToken.ParentId);
  until TargetToken = nil;
  Result := nil;
end;

function TActivityExecutionContext.GetLocalVariable(const Name: string): TValue;
var
  Variable: IVariable;
begin
  Variable := FInstance.GetTokenVariable(Token, Name);
  if Variable <> nil then
    Result := Variable.Value
  else
    Result := TValue.Empty;
end;

function TActivityExecutionContext.GetNode: TFlowNode;
begin
  Result := FContext.Node;
end;

function TActivityExecutionContext.GetVariable(const Name: string): TValue;
var
  Variable: IVariable;
begin
  Variable := FindVariable(Name);
  if Variable <> nil then
    Result := Variable.Value
  else
    Result := TValue.Empty;
end;

procedure TActivityExecutionContext.SetLocalVariable(const Name: string; Value: TValue);
begin
  FInstance.SetTokenVariable(Token, Name, Value);
end;

procedure TActivityExecutionContext.SetVariable(const Name: string; Value: TValue);
begin
  {$Message WARN 'Resolve this'}
  FInstance.SetVariable(Name, Value);
end;

{ TActivityExecutor }

constructor TActivityExecutor.Create(Context: TActivityExecutionContext);
begin
  inherited Create;
  FContext := Context;
end;

end.

