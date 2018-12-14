unit MemoryInstanceData;

interface

uses
  System.Rtti,
  System.SysUtils,
  Generics.Defaults,
  Generics.Collections,
  Octopus.Process;

type
  TMemoryInstanceData = class;
  TInstanceVar = class;

  TMemoryInstanceData = class(TSingletonImplementation, IProcessInstanceData)
  private
    FTokens: TObjectList<TToken>;
    FRemovedTokens: TObjectList<TToken>;
    FVariables: TObjectList<TInstanceVar>;
    function GetVarValue(Name: string; Token: TToken): TValue;
    procedure SetVarValue(Name: string; Token: TToken; Value: TValue);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition); overload;
    function CountTokens: integer;
    function GetTokens: TArray<TToken>; overload;
    function GetTokens(Node: TFlowNode): TArray<TToken>; overload;
    procedure RemoveToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(Name: string): TValue;
    procedure SetVariable(Name: string; Value: TValue);
    function GetLocalVariable(Token: TToken; Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; Name: string; Value: TValue);
    procedure StartInstance(Process: TWorkflowProcess);
  end;

  TInstanceVar = class
    Name: string;
    Value: TValue;
    Token: TToken;
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

function TMemoryInstanceData.GetLocalVariable(Token: TToken; Name: string): TValue;
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

function TMemoryInstanceData.GetVariable(Name: string): TValue;
begin
  result := GetVarValue(Name, nil);
end;

function TMemoryInstanceData.GetVarValue(Name: string; Token: TToken): TValue;
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

procedure TMemoryInstanceData.SetLocalVariable(Token: TToken; Name: string; Value: TValue);
begin
  SetVarValue(Name, Token, Value);
end;

procedure TMemoryInstanceData.SetVariable(Name: string; Value: TValue);
begin
  SetVarValue(Name, nil, Value);
end;

procedure TMemoryInstanceData.SetVarValue(Name: string; Token: TToken; Value: TValue);
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

procedure TMemoryInstanceData.StartInstance(Process: TWorkflowProcess);
var
  variable: TVariable;
begin
  // process variables
  FVariables.Clear;
  for variable in Process.Variables do
    SetVariable(variable.Name, variable.DefaultValue);

   // start token
  FTokens.Clear;
  AddToken(Process.StartNode);
end;

end.

