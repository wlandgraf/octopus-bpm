unit Octopus.Process;

{$I Octopus.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  Generics.Collections,
  System.Rtti,
  Octopus.DataTypes;

type
  TWorkflowProcess = class;
  TFlowNode = class;
  TTransition = class;
  TVariable = class;
  TToken = class;
  TExecutionContext = class;
  TValidationContext = class;

  Persistent = class(TCustomAttribute)
  private
    FPropName: string;
  public
    constructor Create(const APropName: string = '');
    property PropName: string read FPropName;
  end;

  IProcessInstanceData = interface;

  TWorkflowProcess = class
  private
    [Persistent]
    FNodes: TObjectList<TFlowNode>;
    [Persistent]
    FTransitions: TObjectList<TTransition>;
    [Persistent]
    FVariables: TObjectList<TVariable>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure InitInstance(Instance: IProcessInstanceData);
    function StartNode: TFlowNode;
    function FindNode(const AId: string): TFlowNode;
    function FindTransition(const AId: string): TTransition;
    function GetNode(const AId: string): TFlowNode;
    function GetTransition(const AId: string): TTransition;
    function GetVariable(const AName: string): TVariable;
    property Nodes: TObjectList<TFlowNode> read FNodes;
    property Transitions: TObjectList<TTransition> read FTransitions;
    property Variables: TObjectList<TVariable> read FVariables;
  end;

  TFlowElement = class
  private
    FId: string;
  public
    constructor Create; virtual;
    procedure Validate(Context: TValidationContext); virtual; abstract;
    [Persistent]
    property Id: string read FId write FId;
  end;

  IProcessInstanceData = interface
  ['{09517276-EF8B-4CCA-A1F2-85F6F2BFE521}']
    function GetInstanceId: string;
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition; const ParentId: string); overload;
    function GetTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; const Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
  end;

  TFlowNode = class abstract(TFlowElement)
  private
    FIncomingTransitions: TList<TTransition>;
    FOutgoingTransitions: TList<TTransition>;
  protected
    procedure ScanTransitions(Proc: TProc<TTransition>);
    procedure FlowTokens(Context: TExecutionContext);
    procedure DeactivateTokens(Context: TExecutionContext);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Execute(Context: TExecutionContext); virtual; abstract;
    procedure Validate(Context: TValidationContext); override;
    procedure EnumTransitions(Process: TWorkflowProcess);
    function IsStart: boolean; virtual;
    property IncomingTransitions: TList<TTransition> read FIncomingTransitions;
    property OutgoingTransitions: TList<TTransition> read FOutgoingTransitions;
  end;

  TCondition = class
  public
    function Evaluate(Context: TExecutionContext): Boolean; virtual; abstract;
  end;

  TTransition = class(TFlowElement)
  private
    [Persistent]
    FSource: TFlowNode;
    [Persistent]
    FTarget: TFlowNode;
    FCondition: TCondition;
    procedure SetCondition(const Value: TCondition);
  public
    destructor Destroy; override;
    procedure Validate(Context: TValidationContext); override;
    function Evaluate(Context: TExecutionContext): boolean; virtual;
    property Source: TFlowNode read FSource write FSource;
    property Target: TFlowNode read FTarget write FTarget;
    [Persistent]
    property Condition: TCondition read FCondition write SetCondition;
  end;

  TVariable = class
  private
    FName: string;
    FDataType: TOctopusDataType;
    FValue: TValue;
    procedure SetValue(const Value: TValue);
    function GetDataTypeName: string;
    procedure SetDataTypeName(const Value: string);
  public
    constructor Create(const AName: string; const AValue: TValue); overload;
    destructor Destroy; override;
    [Persistent]
    property Name: string read FName write FName;
    property DataType: TOctopusDataType read FDataType write FDataType;
    [Persistent('Type')]
    property DataTypeName: string read GetDataTypeName write SetDataTypeName;
    [Persistent]
    property Value: TValue read FValue write SetValue;
  end;

  TTokenStatus = (Active, Waiting, Finished);

  TToken = class
  private
    FId: string;
    FTransitionId: string;
    FNodeId: string;
    FProducerId: string;
    FConsumerId: string;
    FStatus: TTokenStatus;
    FParentId: string;
    function GetNodeId: string;
    procedure SetNodeId(const Value: string);
    procedure SetTransitionId(const Value: string);
  public
    property Id: string read FId write FId;
    property TransitionId: string read FTransitionId write SetTransitionId;
    property NodeId: string read GetNodeId write SetNodeId;
    property ConsumerId: string read FConsumerId write FConsumerId;
    property ProducerId: string read FProducerId write FProducerId;
    property Status: TTokenStatus read FStatus write FStatus;
    property ParentId: string read FParentId write FParentId;
  end;

  TTokenPredicateFunc = reference to function(Token: TToken): Boolean;

  TExecutionContext = class
  private
    FInstance: IProcessInstanceData;
    FProcess: TWorkflowProcess;
    FNode: TFlowNode;
  public
    constructor Create(AInstance: IProcessInstanceData; AProcess: TWorkflowProcess; ANode: TFlowNode);
    function GetTokens(Predicate: TTokenPredicateFunc): TList<TToken>;
    function LastData(const Variable: string): TValue; overload;
    function LastData(ANode: TFlowNode; const Variable: string): TValue; overload;
    function LastData(const NodeId, Variable: string): TValue; overload;
    property Instance: IProcessInstanceData read FInstance;
    property Process: TWorkflowProcess read FProcess;
    property Node: TFlowNode read FNode;
  end;

  TValidationResult = class
  private
    FElement: TFlowElement;
    FError: boolean;
    FMessage: string;
  public
    constructor Create(AElement: TFlowElement; AError: boolean; const AMessage: string);
    property Element: TFlowElement read FElement;
    property Error: boolean read FError;
    property Message: string read FMessage;
  end;

  TValidationContext = class
  private
    FResults: TList<TValidationResult>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddError(AElement: TFlowElement; const AMessage: string);
    property Results: TList<TValidationResult> read FResults;
  end;

  TTokens = class
  public
    class function Pending(const NodeId: string = ''): TTokenPredicateFunc; static;
    class function Active(const NodeId: string): TTokenPredicateFunc; static;
  end;

implementation

uses
  Octopus.Exceptions,
  Octopus.Global,
  Octopus.Resources;

{ TWorkflowProcess }

constructor TWorkflowProcess.Create;
begin
  FNodes := TObjectList<TFlowNode>.Create;
  FTransitions := TObjectList<TTransition>.Create;
  FVariables := TObjectList<TVariable>.Create;
end;

destructor TWorkflowProcess.Destroy;
begin
  FNodes.Free;
  FTransitions.Free;
  FVariables.Free;
  inherited;
end;

function TWorkflowProcess.FindNode(const AId: string): TFlowNode;
begin
  for result in Nodes do
    if SameText(AId, result.Id) then
      exit;
  result := nil;
end;

function TWorkflowProcess.FindTransition(const AId: string): TTransition;
begin
  for result in Transitions do
    if SameText(AId, result.Id) then
      exit;
  result := nil;
end;

function TWorkflowProcess.GetNode(const AId: string): TFlowNode;
begin
  Result := FindNode(AId);
  if Result = nil then
    raise EOCtopusNodeNotFound.Create(AId);
end;

function TWorkflowProcess.GetTransition(const AId: string): TTransition;
begin
  Result := FindTransition(AId);
  if Result = nil then
    raise EOctopusTransitionNotFound.Create(AId);
end;

function TWorkflowProcess.GetVariable(const AName: string): TVariable;
begin
  for result in Variables do
    if SameText(AName, result.Name) then
      exit;
  result := nil;
end;

procedure TWorkflowProcess.InitInstance(Instance: IProcessInstanceData);
var
  variable: TVariable;
begin
  // process variables
  for variable in Self.Variables do
    Instance.SetVariable(variable.Name, variable.Value);

   // start token
  Instance.AddToken(Self.StartNode);
end;

function TWorkflowProcess.StartNode: TFlowNode;
begin
  for result in Nodes do
    if result.IsStart then
      exit;
  result := nil;
end;

{ TFlowNode }

constructor TFlowNode.Create;
begin
  inherited;
  FIncomingTransitions := TList<TTransition>.Create;
  FOutgoingTransitions := TList<TTransition>.Create;
end;

procedure TFlowNode.DeactivateTokens(Context: TExecutionContext);
var
  token: TToken;
  tokens: TList<TToken>;
begin
  tokens := Context.GetTokens(TTokens.Active(Self.Id));
  try
    for token in tokens do
      Context.Instance.DeactivateToken(token);
  finally
    tokens.Free;
  end;
end;

destructor TFlowNode.Destroy;
begin
  FIncomingTransitions.Free;
  FOutgoingTransitions.Free;
  inherited;
end;

procedure TFlowNode.EnumTransitions(Process: TWorkflowProcess);
var
  Transition: TTransition;
begin
  FIncomingTransitions.Clear;
  FOutgoingTransitions.Clear;
  for Transition in Process.Transitions do
  begin
    if Transition.Target = Self then
      FIncomingTransitions.Add(Transition);
    if Transition.Source = Self then
      FOutgoingTransitions.Add(Transition);
  end;
end;

procedure TFlowNode.FlowTokens(Context: TExecutionContext);
var
  token: TToken;
  tokens: TList<TToken>;
begin
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));
  try
    for token in tokens do
    begin
      Context.Instance.RemoveToken(token);
      ScanTransitions(
        procedure(Transition: TTransition)
        begin
          if Transition.Evaluate(Context) then
            Context.Instance.AddToken(Transition, token.Id);
        end);
    end;
  finally
    tokens.Free;
  end;
end;

function TFlowNode.IsStart: boolean;
begin
  result := false;
end;

procedure TFlowNode.ScanTransitions(Proc: TProc<TTransition>);
var
  Transition: TTransition;
begin
  // scan the outgoing Transitions from a node and execute the callback procedure for each one
  for Transition in OutgoingTransitions do
    Proc(Transition);
end;

procedure TFlowNode.Validate(Context: TValidationContext);
begin
  if IncomingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoIncomingTransition);
end;

{ TToken }

function TToken.GetNodeId: string;
begin
  Result := FNodeId;
end;

procedure TToken.SetNodeId(const Value: string);
begin
  FNodeId := Value;
end;

procedure TToken.SetTransitionId(const Value: string);
begin
  FTransitionId := Value;
end;

{ TTransition }

destructor TTransition.Destroy;
begin
  FreeAndNil(FCondition);
  inherited;
end;

function TTransition.Evaluate(Context: TExecutionContext): boolean;
begin
  if Assigned(FCondition) then
    Result := FCondition.Evaluate(Context)
  else // TODO: condition expression?
    Result := true;
end;

procedure TTransition.SetCondition(const Value: TCondition);
begin
  if FCondition <> Value then
  begin
    FreeAndNil(FCondition);
    FCondition := Value;
  end;
end;

procedure TTransition.Validate(Context: TValidationContext);
begin
  if Source = nil then
    Context.AddError(Self, SErrorNoSourceNode);
  if Target = nil then
    Context.AddError(Self, SErrorNoTargetNode);
end;

{ TExecutionContext }

constructor TExecutionContext.Create(AInstance: IProcessInstanceData;
  AProcess: TWorkflowProcess; ANode: TFlowNode);
begin
  FInstance := AInstance;
  FProcess := AProcess;
  FNode := ANode;
end;

function TExecutionContext.LastData(ANode: TFlowNode; const Variable: string): TValue;
var
  token: TToken;
begin
  token := Instance.LastToken(ANode);
  try
    if token <> nil then
      result := Instance.GetLocalVariable(Token, Variable)
    else
      result := TValue.Empty;
  finally
    token.Free;
  end;
end;

function TExecutionContext.GetTokens(
  Predicate: TTokenPredicateFunc): TList<TToken>;
var
  I: Integer;
begin
  Result := Instance.GetTokens;
  try
    I := 0;
    while I < Result.Count do
    begin
      if not Assigned(Predicate) or Predicate(Result[I]) then
        Inc(I)
      else
        Result.Delete(I);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TExecutionContext.LastData(const NodeId, Variable: string): TValue;
begin
  result := LastData(Process.GetNode(NodeId), Variable);
end;

function TExecutionContext.LastData(const Variable: string): TValue;
begin
  Result := LastData(Node, Variable);
end;

{ TValidationResult }

constructor TValidationResult.Create(AElement: TFlowElement; AError: boolean; const AMessage: string);
begin
  FElement := AElement;
  FError := AError;
  FMessage := AMessage;
end;

{ TValidationContext }

procedure TValidationContext.AddError(AElement: TFlowElement; const AMessage: string);
begin
  FResults.Add(TValidationResult.Create(AElement, true, AMessage));
end;

constructor TValidationContext.Create;
begin
  FResults := TObjectList<TValidationResult>.Create;
end;

destructor TValidationContext.Destroy;
begin
  FResults.Free;
  inherited;
end;

{ TVariable }

constructor TVariable.Create(const AName: string; const AValue: TValue);
begin
  inherited Create;
  FName := AName;
  Value := AValue;
end;

destructor TVariable.Destroy;
begin
  if not FValue.IsEmpty and FValue.IsObject then
    FValue.AsObject.Free;
  inherited;
end;

function TVariable.GetDataTypeName: string;
begin
  if DataType <> nil then
    result := DataType.Name
  else
    result := '';
end;

procedure TVariable.SetDataTypeName(const Value: string);
begin
  if Value <> '' then
    DataType := TOctopusDataTypes.Default.Get(Value)
  else
    DataType := nil;
end;

procedure TVariable.SetValue(const Value: TValue);
begin
  FValue := Value;
  if (FDataType = nil) and not FValue.IsEmpty then
    FDataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);
end;

{ TFlowElement }

constructor TFlowElement.Create;
begin
  FId := TUtils.NewId;
end;

{ Persistent }

constructor Persistent.Create(const APropName: string);
begin
  inherited Create;
  FPropName := APropName;
end;

{ TTokens }

class function TTokens.Active(const NodeId: string): TTokenPredicateFunc;
begin
  Result :=
    function(Token: TToken): Boolean
    begin
      Result := (Token.Status = TTokenStatus.Active) and (Token.NodeId = NodeId);
    end;
end;

class function TTokens.Pending(const NodeId: string = ''): TTokenPredicateFunc;
begin
  Result :=
    function(Token: TToken): Boolean
    begin
      Result := (Token.Status <> TTokenStatus.Finished) and
        ((NodeId = '') or (Token.NodeId = NodeId));
    end;
end;

end.


