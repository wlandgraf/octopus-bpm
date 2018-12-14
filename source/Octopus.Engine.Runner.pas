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
    FPersistedTokens: TList<TToken>;
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

{ TWorkflowRunner }

constructor TWorkflowRunner.Create(Process: TWorkflowProcess; Instance: IProcessInstanceData);
begin
  FProcess := Process;
  FInstance := Instance;

  FPersistedTokens := TList<TToken>.Create;
  FInstanceChecked := false;
  FStatus := TRunnerStatus.None;
end;

destructor TWorkflowRunner.Destroy;
begin
  FPersistedTokens.Free;
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
      if not FPersistedTokens.Contains(token) then
      begin
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
begin
  FPersistedTokens.Clear;
  for node in FProcess.Nodes do
    node.EnumTransitions(FProcess);
end;

function TWorkflowRunner.ProcessNode(Node: TFlowNode): boolean;
var
  context: TExecutionContext;
begin
  context := TExecutionContext.Create(FInstance, FProcess, Node, FPersistedTokens);
  try
    Node.Execute(context);
    result := not context.Error;
  finally
    context.Free;
  end;
end;

function TWorkflowRunner.ProcessToken(Token: TToken): boolean;
begin
  result := ProcessNode(token.Node);
end;

end.

