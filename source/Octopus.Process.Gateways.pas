unit Octopus.Process.Gateways;

{$I Octopus.inc}

interface

uses
  Generics.Collections,
  Octopus.Process;

type
  TGateway = class(TFlowNode)
  protected
    function Active(Context: TExecutionContext): boolean; virtual; abstract;
    procedure Trigger(Context: TExecutionContext); virtual; abstract;
    function FindTransitionToken(Transition: TTransition; Tokens: TArray<TToken>): boolean;
    function FindUpstreamToken(ATransition: TTransition; ATokens: TArray<TToken>): boolean;
  public
    procedure Execute(Context: TExecutionContext); override;
    procedure Validate(Context: TValidationContext); override;
  end;

  TExclusiveGateway = class(TGateway)
  protected
    function Active(Context: TExecutionContext): boolean; override;
    procedure Trigger(Context: TExecutionContext); override;
  end;

  TInclusiveGateway = class(TGateway)
  protected
    function Active(Context: TExecutionContext): boolean; override;
    procedure Trigger(Context: TExecutionContext); override;
  end;

  TParallelGateway = class(TGateway)
  protected
    function Active(Context: TExecutionContext): boolean; override;
    procedure Trigger(Context: TExecutionContext); override;
  end;

implementation

uses
  Octopus.Resources;

{ TGateway }

procedure TGateway.Execute(Context: TExecutionContext);
begin
  if Active(Context) then
    Trigger(Context)
  else
     // if the gateway is not active, mark every incoming token to persist
    DeactivateTokens(Context);
end;

function TGateway.FindTransitionToken(Transition: TTransition; Tokens: TArray<TToken>): boolean;
var
  token: TToken;
begin
  for token in Tokens do
    if token.TransitionId = Transition.Id then
      exit(true);
  result := false;
end;

function TGateway.FindUpstreamToken(ATransition: TTransition; ATokens: TArray<TToken>): boolean;
var
  inVisited, outVisited: TList<TFlowNode>;

  function PathToGateway(Node: TFlowNode): boolean;
  var
    transition: TTransition;
  begin
    result := false;
    if not outVisited.Contains(Node) and (Node.OutgoingTransitions.Count > 0) then
    begin
      outVisited.Add(Node);
      for transition in Node.OutgoingTransitions do
      begin
        if transition.Target = Self then // to the gateway
          result := FindTransitionToken(transition, ATokens)
        else
          result := PathToGateway(transition.Target);
        if result then
          break;
      end;
    end;
  end;

  function FindToken(Node: TFlowNode): boolean;
  var
    transition: TTransition;
  begin
    result := false;
    if not inVisited.Contains(Node) and (Node.IncomingTransitions.Count > 0) then
    begin
      inVisited.Add(Node);
      for transition in Node.IncomingTransitions do
      begin
        if FindTransitionToken(transition, ATokens) then
        begin
          // ignore token if there's a path from the token to a non-empty incoming transition of the gateway
          outVisited.Clear;
          result := not PathToGateway(transition.Target);
        end
        else
          result := FindToken(transition.Source);
        if result then
          break;
      end;
    end;
  end;

begin
  inVisited := TList<TFlowNode>.Create;
  outVisited := TList<TFlowNode>.Create;
  try
    inVisited.Add(Self);
    result := FindToken(ATransition.Source);
  finally
    inVisited.Free;
    outVisited.Free;
  end;
end;

procedure TGateway.Validate(Context: TValidationContext);
begin
  if IncomingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoIncomingTransition);
  if OutgoingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoOutgoingTransition);
end;

{ TExclusiveGateway }

function TExclusiveGateway.Active(Context: TExecutionContext): boolean;
begin
  // exclusive gateway is activated for any incoming token
  Result := Length(Context.GetTokens(TTokens.Active(Self.Id))) > 0;
end;

procedure TExclusiveGateway.Trigger(Context: TExecutionContext);
var
  token: TToken;
  done: boolean;
begin
  // for each incoming token
  for token in Context.GetTokens(TTokens.Active(Self.Id)) do
  begin
    // generate a new token for the first outgoing transition evaluated as true
    done := false;
    ScanTransitions(
      procedure(Transition: TTransition)
      begin
        if not done then
        begin
          if Transition.Evaluate(Context) then
          begin
            Context.Instance.AddToken(Transition);
            done := true;
          end;
        end;
      end);

    // mark the incoming token to remove or persist
    if done then
      Context.Instance.RemoveToken(token)
    else
      Context.Instance.DeactivateToken(token);
  end;
end;

{ TInclusiveGateway }

function TInclusiveGateway.Active(Context: TExecutionContext): boolean;
var
  transition: TTransition;
  tokens: TArray<TToken>;
begin
  // inclusive gateway is activated if:
  // - at least one incoming transition has at least one token; and
  // - for each empty incoming transition, there is no token in the graph anywhere upstream of this sequence flow
  // (unless there's a path from the token to a non-empty incoming transition of the gateway)
  Result := Length(Context.GetTokens(TTokens.Pending(Self.Id))) > 0;
  if Result then
  begin
    tokens := Context.GetTokens(TTokens.Pending());
    for transition in IncomingTransitions do
      if not FindTransitionToken(transition, tokens) and FindUpstreamToken(transition, tokens) then
      begin
        Result := False;
        Break;
      end;
  end;
end;

procedure TInclusiveGateway.Trigger(Context: TExecutionContext);
var
  transition: TTransition;
  tokens: TArray<TToken>;
  I: Integer;
begin
  // get all pending tokens for the node
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));

  // consume one token from each incoming transition that has a token
  for transition in IncomingTransitions do
  begin
    for I := 0 to Length(tokens) - 1 do
      if tokens[I].TransitionId = transition.Id then
      begin
        Context.Instance.RemoveToken(tokens[I]);
        break;
      end;
  end;

  // generate a new token for each outgoing transition evaluated as true
  ScanTransitions(
    procedure(Transition: TTransition)
    begin
      if Transition.Evaluate(Context) then
        Context.Instance.AddToken(Transition);
    end);
end;

{ TParallelGateway }

function TParallelGateway.Active(Context: TExecutionContext): boolean;
var
  transition: TTransition;
  tokens: TArray<TToken>;
begin
  // parallel gateway is activated if there is at least one pending token on each incoming transition
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));
  for transition in IncomingTransitions do
    if not FindTransitionToken(transition, tokens) then
      Exit(False);
  Result := True;
end;

procedure TParallelGateway.Trigger(Context: TExecutionContext);
var
  transition: TTransition;
  tokens: TArray<TToken>;
  I: Integer;
begin
  // get all pending tokens for the node
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));

  // consume one token from each incoming transition that has a token
  for transition in IncomingTransitions do
  begin
    // iterate from oldest to newest, to get the first token arriving to the node
    for I := 0 to Length(tokens) - 1 do
      if tokens[I].TransitionId = transition.Id then
      begin
        Context.Instance.RemoveToken(tokens[I]);
        break;
      end;
  end;

  // generate a new token for each outgoing transition (no evaluation)
  ScanTransitions(
    procedure(Transition: TTransition)
    begin
      Context.Instance.AddToken(Transition);
    end);
end;

end.

