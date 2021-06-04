unit Octopus.Engine.Tokens;

interface

uses
  SysUtils, Generics.Collections,
  Octopus.Persistence.Common,
  Octopus.Process;

type
  TContextTokens = class(TInterfacedObject, ITokensPersistence)
  strict private
    FRuntime: IProcessInstanceData;
    FTokens: TList<TToken>;
    FLoaded: Boolean;
    procedure CheckLoaded;
  public
    constructor Create(ARuntime: IProcessInstanceData);
    destructor Destroy; override;
  public
    { ITokensPersistence }
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition; const ParentId: string); overload;
    function LoadTokens: TList<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
  end;

implementation

{ TContextTokens }

constructor TContextTokens.Create(ARuntime: IProcessInstanceData);
begin
  inherited Create;
  FRuntime := ARuntime;
  FTokens := TList<TToken>.Create;
end;

procedure TContextTokens.DeactivateToken(Token: TToken);
begin
  if Token.Status = TTokenStatus.Waiting then Exit;

  FRuntime.DeactivateToken(Token);
  Token.Status := TTokenStatus.Waiting;
end;

destructor TContextTokens.Destroy;
begin
  FTokens.Free;
  inherited;
end;

procedure TContextTokens.ActivateToken(Token: TToken);
begin
  if Token.Status = TTokenStatus.Active then Exit;

  FRuntime.ActivateToken(Token);
  Token.Status := TTokenStatus.Active;
end;

procedure TContextTokens.AddToken(Transition: TTransition; const ParentId: string);
var
  Token: TToken;
  TokenId: string;
begin
  FRuntime.AddToken(Transition, ParentId);

  Token := TToken.Create;
  FTokens.Add(Token);
  Token.Id := TokenId;
  Token.TransitionId := Transition.Id;
  Token.NodeId := Transition.Target.Id;
  Token.ParentId := ParentId;
end;

procedure TContextTokens.AddToken(Node: TFlowNode);
var
  Token: TToken;
  TokenId: string;
begin
  FRuntime.AddToken(Node);

  Token := TToken.Create;
  FTokens.Add(Token);
  Token.Id := TokenId;
  Token.NodeId := Node.Id;
end;

function TContextTokens.LoadTokens: TList<TToken>;
begin
  CheckLoaded;
  Result := FTokens;
end;

procedure TContextTokens.RemoveToken(Token: TToken);
begin
  if Token.Status = TTokenStatus.Finished then Exit;

  FRuntime.RemoveToken(Token);
  Token.Status := TTokenStatus.Finished;
end;

procedure TContextTokens.CheckLoaded;
begin
  if FLoaded then Exit;

  FTokens.Free;
  FTokens := FRuntime.LoadTokens;
  FLoaded := True;
end;

end.
