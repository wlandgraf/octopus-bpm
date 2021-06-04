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
  FRuntime.DeactivateToken(Token);
end;

destructor TContextTokens.Destroy;
begin
  FTokens.Free;
  inherited;
end;

procedure TContextTokens.ActivateToken(Token: TToken);
begin
  FRuntime.ActivateToken(Token);
end;

procedure TContextTokens.AddToken(Transition: TTransition; const ParentId: string);
begin
  FRuntime.ActivateToken(Transition, ParentId);
end;

procedure TContextTokens.AddToken(Node: TFlowNode);
begin
  FRuntime.AddToken(Node);
end;

function TContextTokens.LoadTokens: TList<TToken>;
begin
  Result := FRuntime.LoadTokens;
end;

procedure TContextTokens.RemoveToken(Token: TToken);
begin
  FRuntime.RemoveToken(Token);
end;

procedure TContextTokens.CheckLoaded;
//var
//  LocalVar: IVariable;
//  MutableVar: IMutableVariable;
begin
  if FLoaded then Exit;

  FTokens.Clear;
//  for LocalVar in FRuntime.LoadTokens do
  begin
//    MutableVar := TMutableVariable.Create(LocalVar.Name, LocalVar.TokenId, LocalVar.Value);
//    FTokens.Add(MutableVar);
  end;
  FLoaded := True;
end;

end.
