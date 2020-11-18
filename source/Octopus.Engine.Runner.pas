unit Octopus.Engine.Runner;

interface

uses
  Generics.Collections,
  Octopus.Process;

type
  TWorkflowRunner = class;

  TRunnerStatus = (None, Processed, Error);

  TWorkflowRunner = class
  private
    FProcess: TWorkflowProcess;
    FInstance: IProcessInstanceData;
    FStatus: TRunnerStatus;
    FInstanceChecked: boolean;
    FProcessedTokens: TList<string>;
    procedure PrepareExecution;
    procedure ProcessNode(Node: TFlowNode);
    procedure ProcessToken(Token: TToken);
  public
    constructor Create(Process: TWorkflowProcess; Instance: IProcessInstanceData);
    destructor Destroy; override;
    procedure Execute;
    property Status: TRunnerStatus read FStatus;
  end;

implementation

uses
  Octopus.Exceptions,
  Octopus.Resources;

{ TWorkflowRunner }

constructor TWorkflowRunner.Create(Process: TWorkflowProcess; Instance: IProcessInstanceData);
begin
  inherited Create;
  FProcessedTokens := TList<string>.Create;
  FProcess := Process;
  FInstance := Instance;

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
  tempToken, token: TToken;
begin
  PrepareExecution;

  repeat
    // Find next active token to process
    token := nil;
    for tempToken in FInstance.GetTokens do
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

    ProcessToken(token);
    FStatus := TRunnerStatus.Processed;
  until False;
end;

procedure TWorkflowRunner.PrepareExecution;
var
  node: TFlowNode;
  token: TToken;
begin
  for token in FInstance.GetTokens do
    if token.Status = TTokenStatus.Waiting then
      FInstance.ActivateToken(token);

  for node in FProcess.Nodes do
    node.EnumTransitions(FProcess);

  FProcessedTokens.Clear;
end;

procedure TWorkflowRunner.ProcessNode(Node: TFlowNode);
var
  context: TExecutionContext;
begin
  context := TExecutionContext.Create(FInstance, FProcess, Node);
  try
    Node.Execute(context);
  finally
    context.Free;
  end;
end;

procedure TWorkflowRunner.ProcessToken(Token: TToken);
begin
  ProcessNode(FProcess.GetNode(token.NodeId));
end;

end.

