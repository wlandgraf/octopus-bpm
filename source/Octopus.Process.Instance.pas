[ DO NOT USE ]
unit Octopus.Process.Instance;

interface

uses
  Generics.Collections,
  System.Rtti,
  Octopus.Process;

type
  TProcessInstance = class;

  TInstanceStatus = (New, Running, Finished, Error);

  TProcessInstance = class(TCustomProcessInstance)
  private
    [Persistent]
    FStatus: TInstanceStatus;
    [Persistent]
    FTokens: TObjectList<TToken>;
    FRemovedTokens: TObjectList<TToken>;
    [Persistent]
    FChecked: boolean;
    [Persistent]
    FData: TDictionary<string,TValue>;
    FDataObjects: TObjectList<TObject>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ActivateTokens;
    function ActiveTokens: integer;
    procedure AddToken(Token: TToken); override;
    function GetActiveTokenActivity(var TokenActivity: TActivity): boolean;
    function GetToken(Activity: TActivity): TToken; overload; override;
    function GetToken(Transition: TTransition): TToken; overload; override;
    function FindToken(Transition: TTransition): boolean; override;
    procedure RemoveToken(Token: TToken); override;
    function LastToken(Activity: TActivity): TToken; overload; override;
    function GetData(Key: string): TValue; override;
    procedure SetData(Key: string; Value: TValue); override;
    procedure InitData(Process: TWorkflowProcess);
    property Status: TInstanceStatus read FStatus write FStatus;
    property Tokens: TObjectList<TToken> read FTokens;
    property Data: TDictionary<string,TValue> read FData;
    property Checked: boolean read FChecked write FChecked;
  end;

implementation

{ TProcessInstance }

procedure TProcessInstance.ActivateTokens;
var
  token: TToken;
begin
  for token in Tokens do
    if token.Status = TTokenStatus.Save then
      token.Status := TTokenStatus.Active;
end;

function TProcessInstance.ActiveTokens: integer;
var
  token: TToken;
begin
  result := 0;
  for token in Tokens do
    if token.Active then
      Inc(result);
end;

procedure TProcessInstance.AddToken(Token: TToken);
begin
  Tokens.Add(Token);
end;

constructor TProcessInstance.Create;
begin
  FTokens := TObjectList<TToken>.Create;
  FRemovedTokens := TObjectList<TToken>.Create;
  FData := TDictionary<string,TValue>.Create;
  FDataObjects := TObjectList<TObject>.Create;
  FStatus := TInstanceStatus.New;
  FChecked := false;
end;

destructor TProcessInstance.Destroy;
begin
  FTokens.Free;
  FRemovedTokens.Free;
  FData.Free;
  FDataObjects.Free;
  inherited;
end;

function TProcessInstance.FindToken(Transition: TTransition): boolean;
var
  token: TToken;
begin
  for token in Tokens do
    if token.Transition = Transition then
      exit(true);
  result := false;
end;

function TProcessInstance.GetActiveTokenActivity(var TokenActivity: TActivity): boolean;
var
  token: TToken;
begin
  for token in Tokens do
  begin
    if token.Active then
    begin
      TokenActivity := token.Activity;
      if Assigned(TokenActivity) then
        exit(true);
    end;
  end;
  result := false;
end;

function TProcessInstance.GetData(Key: string): TValue;
begin
  FData.TryGetValue(Key, result);
end;

function TProcessInstance.GetToken(Transition: TTransition): TToken;
var
  token: TToken;
begin
  // get the first active token for a workflow Transition
  for token in Tokens do
    if token.Active and (token.Transition = Transition) then
      exit(token);
  result := nil;
end;

procedure TProcessInstance.InitData(Process: TWorkflowProcess);
var
  variable: TVariable;
begin
  FData.Clear;
  for variable in Process.Variables do
    FData.Add(variable.Name, variable.DefaultValue);
end;

function TProcessInstance.LastToken(Activity: TActivity): TToken;
var
  token: TToken;
begin
  result := nil;
  for token in FRemovedTokens do
    if (token.Transition <> nil) and (token.Transition.Target = Activity) then
      result := token;
end;

procedure TProcessInstance.RemoveToken(Token: TToken);
begin
  if FTokens.Contains(Token) then
  begin
    FTokens.Extract(Token);
    FRemovedTokens.Add(Token);
  end;
end;

function TProcessInstance.GetToken(Activity: TActivity): TToken;
var
  token: TToken;
begin
  // get the first active incoming token for a workflow activity
  for token in Tokens do
    if token.Active and (token.Activity = Activity) then
      exit(token);
  result := nil;
end;

procedure TProcessInstance.SetData(Key: string; Value: TValue);
begin
  FData.AddOrSetValue(Key, Value);
  if not Value.IsEmpty and Value.IsObject then
    FDataObjects.Add(Value.AsObject);
end;

end.

