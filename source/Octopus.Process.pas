unit Octopus.Process;

{$I Octopus.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  Generics.Collections,
  System.Rtti,
  Aurelius.Validation.Interfaces,
  Aurelius.Validation,
  Octopus.DataTypes;

type
  IValidationContext = Aurelius.Validation.Interfaces.IValidationContext;
  IValidationResult = Aurelius.Validation.Interfaces.IValidationResult;
  TValidationResult = Aurelius.Validation.TValidationResult;
  TValidationError = Aurelius.Validation.TValidationError;

  TWorkflowProcess = class;
  TFlowNode = class;
  TTransition = class;
  TVariable = class;
  TToken = class;
  TExecutionContext = class;
  TTransitionExecutionContext = class;

  Persistent = class(TCustomAttribute)
  private
    FPropName: string;
  public
    constructor Create(const APropName: string = '');
    property PropName: string read FPropName;
  end;

  IProcessInstanceData = interface;

  IVariable = interface
  ['{F73A4AB4-A35B-4076-ADCF-C3295B3369D6}']
    function GetName: string;
    function GetValue: TValue;
    function GetTokenId: string;
    property Name: string read GetName;
    property Value: TValue read GetValue;
    property TokenId: string read GetTokenId;
  end;

  IVariablesPersistence = interface
  ['{E5AB071A-E3F5-48F6-8012-03C335618183}']
    function LoadVariable(const Name: string; const TokenId: string = ''): IVariable;
    procedure SaveVariable(const Name: string; const Value: TValue; const TokenId: string = '');
  end;

  ITokensPersistence = interface
  ['{5FA154EA-E663-4990-BF02-2C891CF6182D}']
    function AddToken(Node: TFlowNode): string; overload;
    function AddToken(Transition: TTransition; const ParentId: string): string; overload;
    function LoadTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
  end;

  TFlowElement = class
  strict private
    FId: string;
  public
    [Persistent]
    property Id: string read FId write FId;
  end;

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
    procedure InitInstance(Instance: IProcessInstanceData; Variables: IVariablesPersistence);
    procedure AutoId(Element: TFlowElement);
    procedure Prepare;
    function StartNode: TFlowNode;
    function FindNode(const AId: string): TFlowNode;
    function FindTransition(const AId: string): TTransition;
    function GetNode(const AId: string): TFlowNode;
    function GetTransition(const AId: string): TTransition;
    property Nodes: TObjectList<TFlowNode> read FNodes;
    property Transitions: TObjectList<TTransition> read FTransitions;
    property Variables: TObjectList<TVariable> read FVariables;
  end;

  IProcessInstanceData = interface
  ['{09517276-EF8B-4CCA-A1F2-85F6F2BFE521}']
    function GetInstanceId: string;
    function AddToken(Node: TFlowNode): string; overload;
    function AddToken(Transition: TTransition; const ParentId: string): string; overload;
    function LoadTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    procedure Lock(TimeoutMS: Integer);
    procedure Unlock;
    procedure Finish;
    procedure SetDueDate(DueDate: TDateTime);
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
    constructor Create;
    destructor Destroy; override;
    procedure Execute(Context: TExecutionContext); virtual; abstract;
    function Validate(Context: IValidationContext): IValidationResult; virtual;
    procedure EnumTransitions(Process: TWorkflowProcess);
    function IsStart: boolean; virtual;
    property IncomingTransitions: TList<TTransition> read FIncomingTransitions;
    property OutgoingTransitions: TList<TTransition> read FOutgoingTransitions;
  end;

  IStorage = IInterface;

  TTokenExecutionContext = class
  strict private
    FToken: TToken;
    FContext: TExecutionContext;
    function GetStorage: IStorage;
  strict protected
    property Context: TExecutionContext read FContext;
  public
    constructor Create(AContext: TExecutionContext; AToken: TToken);
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; Value: TValue);
    function GetLocalVariable(const Name: string): TValue;
    procedure SetLocalVariable(const Name: string; Value: TValue);
    property Token: TToken read FToken;
    property Storage: IStorage read GetStorage;
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
    function Validate(Context: IValidationContext): IValidationResult; virtual;
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

  TTokenPredicateFunc = reference to function(Token: TToken): Boolean;

  TExecutionContext = class
  strict private
    FTokens: TList<TToken>;
    FVariables: IVariablesPersistence;
    FContextTokens: ITokensPersistence;
    FProcess: TWorkflowProcess;
    FNode: TFlowNode;
    FStorage: IStorage;
    function FindToken(const Id: string): TToken;
    function FindVariable(Token: TToken; const Name: string): IVariable;
  protected
    property Tokens: TList<TToken> read FTokens;
  public
    constructor Create(AVariables: IVariablesPersistence; AContextTokens: ITokensPersistence;
      AProcess: TWorkflowProcess; ANode: TFlowNode; AStorage: IStorage);
    function GetTokens(Predicate: TTokenPredicateFunc): TList<TToken>;

    function GetVariable(Token: TToken; const Name: string): TValue;
    procedure SetVariable(Token: TToken; const Name: string; Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; Value: TValue);

    procedure AddToken(Transition: TTransition; Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);

    property Process: TWorkflowProcess read FProcess;
    property Storage: IStorage read FStorage;
    property Node: TFlowNode read FNode;
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

procedure TWorkflowProcess.AutoId(Element: TFlowElement);
var
  Candidate: string;
  Index: Integer;
begin
  if Element.Id <> '' then Exit;

  Index := 0;
  repeat
    Inc(Index);
    Candidate := Format('%s%d', [Element.ClassName, Index]);
    if Candidate[1] = 'T' then
      Delete(Candidate, 1, 1);
  until (FindNode(Candidate) = nil) and (FindTransition(Candidate) = nil);
  Element.Id := Candidate;
end;

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

procedure TWorkflowProcess.InitInstance(Instance: IProcessInstanceData;
  Variables: IVariablesPersistence);
var
  variable: TVariable;
begin
  // process variables
  for variable in Self.Variables do
    Variables.SaveVariable(variable.Name, variable.Value);

   // start token
  Instance.AddToken(Self.StartNode);
end;

procedure TWorkflowProcess.Prepare;
var
  node: TFlowNode;
begin
  for node in Nodes do
    node.EnumTransitions(Self);
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
      Context.DeactivateToken(token);
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
      Context.RemoveToken(token);
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

function TFlowNode.Validate(Context: IValidationContext): IValidationResult;
begin
  if IncomingTransitions.Count = 0 then
    TValidationResult.Failed(SErrorNoIncomingTransition);
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

function TTransition.Validate(Context: IValidationContext): IValidationResult;
begin
  Result := TValidationResult.Create;
  if Source = nil then
    Result.Errors.Add(TValidationError.Create(SErrorNoSourceNode));
  if Target = nil then
    Result.Errors.Add(TValidationError.Create(SErrorNoTargetNode));
end;

{ TExecutionContext }

procedure TExecutionContext.AddToken(Transition: TTransition; Token: TToken);
begin
  if Token <> nil then
    FContextTokens.AddToken(Transition, Token.Id)
  else
    FContextTokens.AddToken(Transition, '');
end;

constructor TExecutionContext.Create(AVariables: IVariablesPersistence;
  AContextTokens: ITokensPersistence; AProcess: TWorkflowProcess; ANode: TFlowNode;
  AStorage: IStorage);
begin
  inherited Create;
  FContextTokens := AContextTokens;
  FVariables := AVariables;
  FTokens := FContextTokens.LoadTokens;;
  FProcess := AProcess;
  FNode := ANode;
  FStorage := AStorage;
end;

procedure TExecutionContext.DeactivateToken(Token: TToken);
begin
  FContextTokens.DeactivateToken(Token);
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
    Result := FVariables.LoadVariable(Name, Token.Id);
    if Result <> nil then
      Exit;
    Token := FindToken(Token.ParentId);
  end;
  Result := FVariables.LoadVariable(Name);
end;

function TExecutionContext.GetLocalVariable(Token: TToken;
  const Name: string): TValue;
var
  Variable: IVariable;
begin
  if Token <> nil then
    Variable := FVariables.LoadVariable(Name, Token.Id)
  else
    Variable := FVariables.LoadVariable(Name);
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

procedure TExecutionContext.RemoveToken(Token: TToken);
begin
  FContextTokens.RemoveToken(Token);
end;

procedure TExecutionContext.SetLocalVariable(Token: TToken; const Name: string;
  Value: TValue);
begin
  if Token <> nil then
    FVariables.SaveVariable(Name, Value, Token.Id)
  else
    FVariables.SaveVariable(Name, Value);
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
    FVariables.SaveVariable(Name, Value, Variable.TokenId)
  else
    // set global variable
    FVariables.SaveVariable(Name, Value);
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

function TTokenExecutionContext.GetStorage: IStorage;
begin
  Result := FContext.Storage;
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


