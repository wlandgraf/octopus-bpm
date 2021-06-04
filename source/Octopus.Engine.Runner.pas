unit Octopus.Engine.Runner;

interface

uses
  Generics.Collections, SysUtils, DateUtils,
  Aurelius.Drivers.Interfaces,
  Octopus.Process;

type
  TWorkflowRunner = class;

  TRunnerStatus = (None, Processed, Error);

  TWorkflowRunner = class
  private
    FProcess: TWorkflowProcess;
    FInstance: IProcessInstanceData;
    FVariables: IVariablesPersistence;
    FTokens: ITokensPersistence;
    FStatus: TRunnerStatus;
    FInstanceChecked: boolean;
    FProcessedTokens: TList<string>;
    FConnection: IDBConnection;
    FLockTimeoutMS: Integer;
    FDueDateIntervalMS: Int64;
    procedure PrepareExecution;
    procedure ProcessNode(Node: TFlowNode);
    procedure InternalExecute;
  public
    constructor Create(Process: TWorkflowProcess; Instance: IProcessInstanceData;
      Variables: IVariablesPersistence; Connection: IDBConnection);
    destructor Destroy; override;
    procedure Execute;
    property Status: TRunnerStatus read FStatus;
    property DueDateIntervalMS: Int64 read FDueDateIntervalMS write FDueDateIntervalMS;
  end;

implementation

uses
  Octopus.Engine.Tokens,
  Octopus.Exceptions,
  Octopus.Resources;

{ TWorkflowRunner }

constructor TWorkflowRunner.Create(Process: TWorkflowProcess; Instance: IProcessInstanceData;
  Variables: IVariablesPersistence; Connection: IDBConnection);
begin
  inherited Create;
  FLockTimeoutMS := 5 * 60 * 1000; // 5 minutes
  FDueDateIntervalMS := 30 * 60 * 1000; // 30 minutes
  FProcessedTokens := TList<string>.Create;
  FProcess := Process;
  FInstance := Instance;
  FVariables := Variables;
  FConnection := Connection;

  FInstanceChecked := false;
  FStatus := TRunnerStatus.None;
end;

destructor TWorkflowRunner.Destroy;
begin
  FProcessedTokens.Free;
  inherited;
end;

procedure TWorkflowRunner.Execute;
var
  Token: TToken;
  Tokens: TList<TToken>;
  Finished: Boolean;
begin
  FInstance.Lock(FLockTimeoutMS);
  try
    FTokens := TContextTokens.Create(FInstance);
    FInstance.SetDueDate(IncMilliSecond(Now, DueDateIntervalMS));
    InternalExecute;
    Finished := True;
    Tokens := FTokens.LoadTokens;
    for Token in tokens do
      if Token.Status <> TTokenStatus.Finished then
      begin
        Finished := False;
        break;
      end;
    if Finished then
      FInstance.Finish;
  finally
    FInstance.Unlock;
  end;
end;

procedure TWorkflowRunner.InternalExecute;
var
  tempToken, token: TToken;
  tokens: TList<TToken>;
begin
  PrepareExecution;

  repeat
    // Find next active token to process
    tokens := FTokens.LoadTokens;
    token := nil;
    for tempToken in tokens do
      if tempToken.Status = TTokenStatus.Active then
      begin
        token := tempToken;
        break;
      end;

    // if no active token remaining, we're done
    if token = nil then Exit;

    // Avoid infinite loop
    if FProcessedTokens.Contains(Token.Id) then
      raise EOctopusException.CreateFmt(SErrorTokenReprocessed, [token.Id]);
    FProcessedTokens.Add(token.Id);

    ProcessNode(FProcess.GetNode(token.NodeId));
    FStatus := TRunnerStatus.Processed;
  until False;
end;

procedure TWorkflowRunner.PrepareExecution;
var
  token: TToken;
  tokens: TList<TToken>;
begin
  tokens := FTokens.LoadTokens;
  for token in tokens do
    if token.Status = TTokenStatus.Waiting then
      FTokens.ActivateToken(token);
  FProcess.Prepare;

  FProcessedTokens.Clear;
end;

procedure TWorkflowRunner.ProcessNode(Node: TFlowNode);
var
  context: TExecutionContext;
  trans: IDBTransaction;
begin
  context := TExecutionContext.Create(FVariables, FTokens, FProcess, Node, FConnection);
  try
    trans := FConnection.BeginTransaction;
    try
      Node.Execute(context);
      trans.Commit;
    except
      trans.Rollback;
      raise;
    end;
  finally
    context.Free;
  end;
end;

end.

