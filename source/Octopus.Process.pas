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
  TTransitionExecutionContext = class;

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

  IVariable = interface
  ['{F73A4AB4-A35B-4076-ADCF-C3295B3369D6}']
    function GetName: string;
    function GetValue: TValue;
    function GetTokenId: string;
    property Name: string read GetName;
    property Value: TValue read GetValue;
    property TokenId: string read GetTokenId;
  end;

  IProcessInstanceData = interface
  ['{09517276-EF8B-4CCA-A1F2-85F6F2BFE521}']
    function GetInstanceId: string;
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition; const ParentId: string); overload;
    function LoadTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    function LoadVariable(const Name: string; const TokenId: string = ''): IVariable;
    procedure SaveVariable(const Name: string; const Value: TValue; const TokenId: string = '');
  end;

  TFlowNode = class abstract(TFlowElement)
  private
    FIncomingTransitions: TList<TTransition>;
    FOutgoingTransitions: TList<TTransition>;
  protected
    procedure ScanTransitions(Context: TExecutionContext; Token: TToken;
      Proc: TProc<TTransitionExecutionContext>);
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

  TTokenExecutionContext = class
  strict private
    FToken: TToken;
    FContext: TExecutionContext;
  strict protected
    property Context: TExecutionContext read FContext;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken);
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; Value: TValue);
    function GetLocalVariable(const Name: string): TValue;
    procedure SetLocalVariable(const Name: string; Value: TValue);
    property Token: TToken read FToken;
  end;

  TTransitionExecutionContext = class(TTokenExecutionContext)
  strict private
    FTransition: TTransition;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken;
      ATransition: TTransition); reintroduce;
    property Transition: TTransition read FTransition;
  end;

  TCondition = class
  public
    function Evaluate(Context: TTransitionExecutionContext): Boolean; virtual; abstract;
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
    function Evaluate(Context: TTransitionExecutionContext): Boolean; virtual;
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

  IStorage = interface
  ['{BDDCC6DA-89CC-47FC-961E-8B059AF79EC9}']
  end;

  TTokenPredicateFunc = reference to function(Token: TToken): Boolean;

  TExecutionContext = class
  strict private
    FTokens: TList<TToken>;
    FInstance: IProcessInstanceData;
    FProcess: TWorkflowProcess;
    FNode: TFlowNode;
    FStorage: IStorage;
    function FindToken(const Id: string): TToken;
    function FindVariable(Token: TToken; const Name: string): IVariable;
  protected
    property Tokens: TList<TToken> read FTokens;
  public
    constructor Create(ATokens: TList<TToken>; AInstance: IProcessInstanceData;
      AProcess: TWorkflowProcess; ANode: TFlowNode; AStorage: IStorage);
    function GetTokens(Predicate: TTokenPredicateFunc): TList<TToken>;

    function GetVariable(Token: TToken; const Name: string): TValue;
    procedure SetVariable(Token: TToken; const Name: string; Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; Value: TValue);

    procedure AddToken(Transition: TTransition; Token: TToken);

    property Instance: IProcessInstanceData read FInstance;
    property Process: TWorkflowProcess read FProcess;
    property Storage: IStorage read FStorage;
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

procedure TWorkflowProcess.InitInstance(Instance: IProcessInstanceData);
var
  variable: TVariable;
begin
  // process variables
  for variable in Self.Variables do
    Instance.SaveVariable(variable.Name, variable.Value);

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
      ScanTransitions(Context, token,
        procedure(Ctxt: TTransitionExecutionContext)
        begin
          if Ctxt.Transition.Evaluate(Ctxt) then
            Context.AddToken(Ctxt.Transition, token);
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

procedure TFlowNode.ScanTransitions(Context: TExecutionContext; Token: TToken;
  Proc: TProc<TTransitionExecutionContext>);
var
  Transition: TTransition;
  TransitionContext: TTransitionExecutionContext;
begin
  // scan the outgoing Transitions from a node and execute the callback procedure for each one
  for Transition in OutgoingTransitions do
  begin
    TransitionContext := TTransitionExecutionContext.Create(Context, Token, Transition);
    try
      Proc(TransitionContext);
    finally
      TransitionContext.Free;
    end;
  end;
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

function TTransition.Evaluate(Context: TTransitionExecutionContext): boolean;
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

procedure TExecutionContext.AddToken(Transition: TTransition; Token: TToken);
begin
  if Token <> nil then
    FInstance.AddToken(Transition, Token.Id)
  else
    FInstance.AddToken(Transition, '');
end;

constructor TExecutionContext.Create(ATokens: TList<TToken>;
  AInstance: IProcessInstanceData; AProcess: TWorkflowProcess; ANode: TFlowNode;
  AStorage: IStorage);
begin
  inherited Create;
  FTokens := ATokens;
  FInstance := AInstance;
  FProcess := AProcess;
  FNode := ANode;
  FStorage := AStorage;
end;

function TExecutionContext.FindToken(const Id: string): TToken;
var
  I: Integer;
begin
  // search from newest to oldest because we are likely to search active token
  // than historical ones
  for I := Tokens.Count -1 downto 0 do
    if Tokens[I].Id = Id then
      Exit(Tokens[I]);
  Result := nil;
end;

function TExecutionContext.FindVariable(Token: TToken; const Name: string): IVariable;
begin
  // Optimize this later!
  while Token <> nil do
  begin
    Result := FInstance.LoadVariable(Name, Token.Id);
    if Result <> nil then
      Exit;
    Token := FindToken(Token.ParentId);
  end;
  Result := FInstance.LoadVariable(Name);
end;

function TExecutionContext.GetLocalVariable(Token: TToken;
  const Name: string): TValue;
var
  Variable: IVariable;
begin
  if Token <> nil then
    Variable := FInstance.LoadVariable(Name, Token.Id)
  else
    Variable := FInstance.LoadVariable(Name);
  if Variable <> nil then
    Result := Variable.Value
  else
    Result := TValue.Empty;
end;

function TExecutionContext.GetTokens(
  Predicate: TTokenPredicateFunc): TList<TToken>;
var
  I: Integer;
begin
  Result := TList<TToken>.Create;
  try
    for I := 0 to Tokens.Count - 1 do
      if not Assigned(Predicate) or Predicate(Tokens[I]) then
        Result.Add(Tokens[I]);
  except
    Result.Free;
    raise;
  end;
end;

function TExecutionContext.GetVariable(Token: TToken;
  const Name: string): TValue;
var
  Variable: IVariable;
begin
  Variable := FindVariable(Token, Name);
  if Variable <> nil then
    Result := Variable.Value
  else
    Result := TValue.Empty;
end;

procedure TExecutionContext.SetLocalVariable(Token: TToken; const Name: string;
  Value: TValue);
begin
  if Token <> nil then
    FInstance.SaveVariable(Name, Value, Token.Id)
  else
    FInstance.SaveVariable(Name, Value);
end;

procedure TExecutionContext.SetVariable(Token: TToken; const Name: string;
  Value: TValue);
var
  Variable: IVariable;
begin
  // check if we already have a variable in scope. If we do, update it, otherwise
  // create a new one
  Variable := FindVariable(Token, Name);
  if (Variable <> nil) then
    FInstance.SaveVariable(Name, Value, Variable.TokenId)
  else
    // set global variable
    FInstance.SaveVariable(Name, Value);
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

{ TTokenExecutionContext }

constructor TTokenExecutionContext.Create(AContext: TExecutionContext;
  AToken: TToken);
begin
  inherited Create;
  FContext := AContext;
  FToken := AToken;
end;

function TTokenExecutionContext.GetLocalVariable(const Name: string): TValue;
begin
  Result := FContext.GetLocalVariable(Token, Name);
end;

function TTokenExecutionContext.GetVariable(const Name: string): TValue;
begin
  Result := FContext.GetVariable(Token, Name);
end;

procedure TTokenExecutionContext.SetLocalVariable(const Name: string;
  Value: TValue);
begin
  FContext.SetLocalVariable(Token, Name, Value);
end;

procedure TTokenExecutionContext.SetVariable(const Name: string; Value: TValue);
begin
  FContext.SetVariable(Token, Name, Value);
end;

{ TTransitionExecutionContext }

constructor TTransitionExecutionContext.Create(AContext: TExecutionContext;
  AToken: TToken; ATransition: TTransition);
begin
  inherited Create(AContext, AToken);
  FTransition := ATransition;
end;

end.


