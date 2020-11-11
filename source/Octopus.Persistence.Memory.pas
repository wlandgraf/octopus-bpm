unit Octopus.Persistence.Memory;

interface

uses
  System.Rtti,
  System.SysUtils,
  Generics.Defaults,
  Generics.Collections,
  Octopus.Persistence.Common,
  Octopus.Process;

type
  TInstanceVar = class
    Name: string;
    Value: TValue;
    Token: TToken;
  end;

  TMemoryInstanceData = class(TInterfacedObject, IProcessInstanceData)
  private
    FTokens: TObjectList<TToken>;
    FRemovedTokens: TObjectList<TToken>;
    FVariables: TObjectList<TInstanceVar>;
    function GetVarValue(const Name: string; Token: TToken): TValue;
    procedure SetVarValue(const Name: string; Token: TToken; Value: TValue);
  public
    constructor Create;
    destructor Destroy; override;
  public
    { IProcessInstanceData methods }
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition); overload;
    function CountTokens: integer;
    function GetTokens: TArray<TToken>; overload;
    function GetTokens(Node: TFlowNode): TArray<TToken>; overload;
    procedure RemoveToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; const Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
  end;

  TMemoryRepository = class(TInterfacedObject, IOctopusRepository)
  public
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
    function PublishDefinition(const Name, JsonDefinition: string): string;
  end;

implementation

{ TMemoryInstanceData }

procedure TMemoryInstanceData.AddToken(Node: TFlowNode);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Node := Node;
  FTokens.Add(token);
end;

procedure TMemoryInstanceData.AddToken(Transition: TTransition);
var
  token: TToken;
begin
  token := TToken.Create;
  token.Transition := Transition;
  FTokens.Add(token);
end;

function TMemoryInstanceData.CountTokens: integer;
begin
  result := FTokens.Count;
end;

constructor TMemoryInstanceData.Create;
begin
  FTokens := TObjectList<TToken>.Create;
  FRemovedTokens := TObjectList<TToken>.Create;
  FVariables := TObjectList<TInstanceVar>.Create;
end;

destructor TMemoryInstanceData.Destroy;
begin
  FTokens.Free;
  FRemovedTokens.Free;
  FVariables.Free;
  inherited;
end;

function TMemoryInstanceData.GetLocalVariable(Token: TToken; const Name: string): TValue;
begin
  result := GetVarValue(Name, Token);
end;

function TMemoryInstanceData.GetTokens: TArray<TToken>;
begin
  result := FTokens.ToArray;
end;

function TMemoryInstanceData.GetTokens(Node: TFlowNode): TArray<TToken>;
var
  token: TToken;
begin
  SetLength(result, 0);
  for token in FTokens do
    if token.Node = Node then
    begin
      SetLength(result, Length(result) + 1);
      result[Length(result) - 1] := token;
    end;
end;

function TMemoryInstanceData.GetVariable(const Name: string): TValue;
begin
  result := GetVarValue(Name, nil);
end;

function TMemoryInstanceData.GetVarValue(const Name: string; Token: TToken): TValue;
var
  ivar: TInstanceVar;
begin
  for ivar in FVariables do
    if SameText(ivar.Name, Name) and (ivar.Token = Token) then
      exit(ivar.Value);
  result := TValue.Empty;
end;

function TMemoryInstanceData.LastToken(Node: TFlowNode): TToken;
var
  token: TToken;
begin
  result := nil;
  for token in FRemovedTokens do
    if (token.Transition <> nil) and (token.Transition.Target = Node) then
      result := token;
end;

procedure TMemoryInstanceData.RemoveToken(Token: TToken);
begin
  if FTokens.Contains(Token) then
  begin
    FTokens.Extract(Token);
    FRemovedTokens.Add(Token);
  end;
end;

procedure TMemoryInstanceData.SetLocalVariable(Token: TToken;
  const Name: string; const Value: TValue);
begin
  SetVarValue(Name, Token, Value);
end;

procedure TMemoryInstanceData.SetVariable(const Name: string; const Value: TValue);
begin
  SetVarValue(Name, nil, Value);
end;

procedure TMemoryInstanceData.SetVarValue(const Name: string; Token: TToken; Value: TValue);
var
  ivar: TInstanceVar;
begin
  for ivar in FVariables do
    if SameText(ivar.Name, Name) and (ivar.Token = Token) then
    begin
      ivar.Value := Value;
      exit;
    end;

  ivar := TInstanceVar.Create;
  ivar.Name := Name;
  ivar.Value := Value;
  ivar.Token := Token;
  FVariables.Add(ivar);
end;

{ TMemoryInstancePersistence }

function TMemoryRepository.CreateInstance(
  const ProcessId: string): IProcessInstanceData;
begin
  Result := TMemoryInstanceData.Create;
end;

function TMemoryRepository.PublishDefinition(const Name,
  JsonDefinition: string): string;
begin

end;

end.

