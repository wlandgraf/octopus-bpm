unit Octopus.Process.Gateways;

{$I Octopus.inc}

interface

uses
  Windows, SysUtils,
  Generics.Collections,
  Octopus.CommonAncestor,
  Octopus.Process;

type
  TGateway = class(TFlowNode)
  protected
    function Active(Context: TExecutionContext): boolean; virtual; abstract;
    procedure Trigger(Context: TExecutionContext); virtual; abstract;
    function FindTransitionToken(Transition: TTransition; Tokens: TList<TToken>): boolean;
    function FindUpstreamToken(ATransition: TTransition; ATokens: TList<TToken>): boolean;
  public
    procedure Execute(Context: TExecutionContext); override;
    function Validate(Context: IValidationContext): IValidationResult; override;
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

function TGateway.FindTransitionToken(Transition: TTransition; Tokens: TList<TToken>): boolean;
var
  token: TToken;
begin
  for token in Tokens do
    if token.TransitionId = Transition.Id then
      exit(true);
  result := false;
end;

function TGateway.FindUpstreamToken(ATransition: TTransition; ATokens: TList<TToken>): boolean;
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

function TGateway.Validate(Context: IValidationContext): IValidationResult;
begin
  Result := TValidationResult.Create;
  if IncomingTransitions.Count = 0 then
    Result.Errors.Add(TValidationError.Create(SErrorNoIncomingTransition));
  if OutgoingTransitions.Count = 0 then
    Result.Errors.Add(TValidationError.Create(SErrorNoOutgoingTransition));
end;

{ TExclusiveGateway }

function TExclusiveGateway.Active(Context: TExecutionContext): boolean;
var
  Tokens: TList<TToken>;
begin
  // exclusive gateway is activated for any incoming token
  Tokens := Context.GetTokens(TTokens.Active(Self.Id));
  try
    Result := Tokens.Count > 0;
  finally
    Tokens.Free;
  end;
end;

procedure TExclusiveGateway.Trigger(Context: TExecutionContext);
var
  token: TToken;
  done: boolean;
  tokens: TList<TToken>;
begin
  // for each incoming token
  tokens := Context.GetTokens(TTokens.Active(Self.Id));
  try
    for token in tokens do
    begin
      // generate a new token for the first outgoing transition evaluated as true
      done := false;
      ScanTransitions(Context, token,
        procedure(Ctxt: TTransitionExecutionContext)
        begin
          if not done then
          begin
            if Ctxt.Transition.Evaluate(Ctxt) then
            begin
              Context.AddToken(Ctxt.Transition, token);
              done := true;
            end;
          end;
        end);

      // mark the incoming token to remove or persist
      if done then
        Context.RemoveToken(token)
      else
        Context.DeactivateToken(token);
    end;
  finally
    tokens.Free;
  end;
end;

{ TInclusiveGateway }

function TInclusiveGateway.Active(Context: TExecutionContext): boolean;
var
  transition: TTransition;
  tokens: TList<TToken>;
begin
  // inclusive gateway is activated if:
  // - at least one incoming transition has at least one token; and
  // - for each empty incoming transition, there is no token in the graph anywhere upstream of this sequence flow
  // (unless there's a path from the token to a non-empty incoming transition of the gateway)
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));
  try
    Result := tokens.Count > 0;
  finally
    tokens.Free;
  end;
  if Result then
  begin
    tokens := Context.GetTokens(TTokens.Pending());
    try
      for transition in IncomingTransitions do
        if not FindTransitionToken(transition, tokens) and FindUpstreamToken(transition, tokens) then
        begin
          Result := False;
          Break;
        end;
    finally
      tokens.Free;
    end;
  end;
end;

procedure TInclusiveGateway.Trigger(Context: TExecutionContext);
var
  transition: TTransition;
  allTokens: TList<TToken>;
  tokensToConsume: TList<Integer>;
  I: Integer;
  ParentToken: TToken;
begin
  // get all tokens of the instance
  allTokens := Context.GetTokens(nil);
  tokensToConsume := TList<Integer>.Create;
  try
    // consume one active token per transition
    for transition in IncomingTransitions do
      for I := 0 to allTokens.Count - 1 do
        // if the token is in the incoming transition and is not finished, consume it,
        // and only it
        if (allTokens[I].TransitionId = transition.Id) and (allTokens[I].Status <> TTokenStatus.Finished) then
        begin
          tokensToConsume.Add(I);
          break;
        end;

    Assert(tokensToConsume.Count > 0);

    // Find the common ancestor for all input tokens (tokens that will be consumed)
    ParentToken := TCommonAncestorFinder.GetCommonAncestorToken(allTokens, tokensToConsume);

    // Consume tokens
    for I := 0 to tokensToConsume.Count - 1 do
      Context.RemoveToken(allTokens[tokensToConsume[I]]);

    // generate a new token for each outgoing transition evaluated as true
    ScanTransitions(Context, ParentToken,
      procedure(Ctxt: TTransitionExecutionContext)
      begin
        if Ctxt.Transition.Evaluate(Ctxt) then
          Context.AddToken(Ctxt.Transition, ParentToken);
      end);
  finally
    tokensToConsume.Free;
    allTokens.Free;
  end;
end;

{ TParallelGateway }

function TParallelGateway.Active(Context: TExecutionContext): boolean;
var
  transition: TTransition;
  tokens: TList<TToken>;
begin
  // parallel gateway is activated if there is at least one pending token on each incoming transition
  tokens := Context.GetTokens(TTokens.Pending(Self.Id));
  try
    for transition in IncomingTransitions do
      if not FindTransitionToken(transition, tokens) then
        Exit(False);
    Result := True;
  finally
    tokens.Free;
  end;
end;

procedure TParallelGateway.Trigger(Context: TExecutionContext);
var
  transition: TTransition;
  allTokens: TList<TToken>;
  tokensToConsume: TList<Integer>;
  I: Integer;
  ParentToken: TToken;
begin
  // get all tokens of the instance
  allTokens := Context.GetTokens(nil);
  tokensToConsume := TList<Integer>.Create;
  try
    // consume one active token per transition
    for transition in IncomingTransitions do
      for I := 0 to allTokens.Count - 1 do
        // if the token is in the incoming transition and is not finished, consume it,
        // and only it
        if (allTokens[I].TransitionId = transition.Id) and (allTokens[I].Status <> TTokenStatus.Finished) then
        begin
          tokensToConsume.Add(I);
          break;
        end;

//    for I := 0 to allTokens.Count - 1 do
//      OutputdebugString(PChar(Format('%d - %s, %s',
//        [I, allTokens[I].Id, allTokens[I].ParentId])));

    // Find the common ancestor for all input tokens (tokens that will be consumed)
    ParentToken := TCommonAncestorFinder.GetCommonAncestorToken(allTokens, tokensToConsume);

    // Consume tokens
    for I := 0 to tokensToConsume.Count - 1 do
      Context.RemoveToken(allTokens[tokensToConsume[I]]);

    // generate a new token for each outgoing transition (no evaluation)
    ScanTransitions(Context, ParentToken,
      procedure(Ctxt: TTransitionExecutionContext)
      begin
        Context.AddToken(Ctxt.Transition, ParentToken);
      end);
  finally
    tokensToConsume.Free;
    allTokens.Free;
  end;
end;

end.

