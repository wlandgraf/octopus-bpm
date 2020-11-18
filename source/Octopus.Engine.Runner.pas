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
    function ProcessNode(Node: TFlowNode): boolean;
    function ProcessToken(Token: TToken): boolean;
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
  tokens: TArray<TToken>;
  token: TToken;
  done: boolean;
begin
  PrepareExecution;

  repeat
    done := true;
    tokens := FInstance.GetTokens;

    for token in tokens do
    begin
      if token.Status = TTokenStatus.Active then
      begin
        // Avoid infinite loop
        if FProcessedTokens.Contains(Token.Id) then
          raise EOctopusException.CreateFmt(SErrorTokenReprocessed, [token.Id]);

        FProcessedTokens.Add(token.Id);
        done := false;
        if ProcessToken(token) then
        begin
          FStatus := TRunnerStatus.Processed;
          break;
        end
        else
        begin // TODO: error handling
          FStatus := TRunnerStatus.Error;
          exit;
        end;
      end;
    end;
  until done;
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

function TWorkflowRunner.ProcessNode(Node: TFlowNode): boolean;
var
  context: TExecutionContext;
begin
  context := TExecutionContext.Create(FInstance, FProcess, Node);
  try
    Node.Execute(context);
    result := not context.Error;
  finally
    context.Free;
  end;
end;

function TWorkflowRunner.ProcessToken(Token: TToken): boolean;
begin
  result := ProcessNode(FProcess.GetNode(token.NodeId));
end;

end.

