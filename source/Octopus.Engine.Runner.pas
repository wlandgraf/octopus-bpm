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
    FVariables: IVariablesPersistence;
    FStatus: TRunnerStatus;
    FInstanceChecked: boolean;
    FProcessedTokens: TList<string>;
    FStorage: IStorage;
    procedure PrepareExecution;
    procedure ProcessNode(Tokens: TList<TToken>; Node: TFlowNode);
  public
    constructor Create(Process: TWorkflowProcess; Instance: IProcessInstanceData;
      Variables: IVariablesPersistence; Storage: IStorage);
    destructor Destroy; override;
    procedure Execute;
    property Status: TRunnerStatus read FStatus;
  end;

implementation

uses
  Octopus.Exceptions,
  Octopus.Resources;

{ TWorkflowRunner }

constructor TWorkflowRunner.Create(Process: TWorkflowProcess; Instance: IProcessInstanceData;
  Variables: IVariablesPersistence; Storage: IStorage);
begin
  inherited Create;
  FProcessedTokens := TList<string>.Create;
  FProcess := Process;
  FInstance := Instance;
  FVariables := Variables;
  FStorage := Storage;

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
  tokens: TList<TToken>;
begin
  PrepareExecution;

  repeat
    // Find next active token to process
    tokens := FInstance.LoadTokens;
    try
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

      ProcessNode(tokens, FProcess.GetNode(token.NodeId));
      FStatus := TRunnerStatus.Processed;
    finally
      tokens.Free;
    end;
  until False;
end;

procedure TWorkflowRunner.PrepareExecution;
var
  node: TFlowNode;
  token: TToken;
  tokens: TList<TToken>;
begin
  tokens := FInstance.LoadTokens;
  try
    for token in tokens do
      if token.Status = TTokenStatus.Waiting then
        FInstance.ActivateToken(token);
  finally
    tokens.Free;
  end;

  for node in FProcess.Nodes do
    node.EnumTransitions(FProcess);

  FProcessedTokens.Clear;
end;

procedure TWorkflowRunner.ProcessNode(Tokens: TList<TToken>; Node: TFlowNode);
var
  context: TExecutionContext;
begin
  context := TExecutionContext.Create(Tokens, FInstance, FVariables, FProcess, Node, FStorage);
  try
    Node.Execute(context);
  finally
    context.Free;
  end;
end;

end.

