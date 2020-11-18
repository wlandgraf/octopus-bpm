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
    function GetTokens: TArray<TToken>; overload;
    procedure ActivateToken(Token: TToken);
    procedure RemoveToken(Token: TToken);
    procedure DeactivateToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(const Name: string): TValue;
    procedure SetVariable(const Name: string; const Value: TValue);
    function GetLocalVariable(Token: TToken; const Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; const Name: string; const Value: TValue);
  end;

  TMemoryRepository = class(TInterfacedObject, IOctopusRepository)
  strict private
    FDefinitions: TObjectDictionary<string, TWorkflowProcess>;
  public
    constructor Create;
    destructor Destroy; override;
    function PublishDefinition(const Name: string; Process: TWorkflowProcess): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
  end;

  TMemoryRuntime = class(TInterfacedObject, IOctopusRuntime)
  public
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

function NewId: string;
var
  S: string;
begin
  S := LowerCase(GuidToString(TGuid.NewGuid));
  S := Copy(S, 2, 8) + Copy(S, 11, 4) + Copy(S, 16, 4) + Copy(S, 21, 4) + Copy(S, 26, 12);
  Result := S;
end;

{ TMemoryInstanceData }

procedure TMemoryInstanceData.AddToken(Node: TFlowNode);
var
  token: TToken;
begin
  token := TToken.Create;
  token.NodeId := Node.Id;
  FTokens.Add(token);
end;

procedure TMemoryInstanceData.ActivateToken(Token: TToken);
begin

end;

procedure TMemoryInstanceData.AddToken(Transition: TTransition);
var
  token: TToken;
begin
  token := TToken.Create;
  token.TransitionId := Transition.Id;
  token.NodeId := Transition.Target.Id;
  FTokens.Add(token);
end;

constructor TMemoryInstanceData.Create;
begin
  FTokens := TObjectList<TToken>.Create;
  FRemovedTokens := TObjectList<TToken>.Create;
  FVariables := TObjectList<TInstanceVar>.Create;
end;

procedure TMemoryInstanceData.DeactivateToken(Token: TToken);
begin

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
    if token.NodeId = Node.Id then
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

{ TMemoryRepository }

constructor TMemoryRepository.Create;
begin
  inherited Create;
  FDefinitions := TObjectDictionary<string, TWorkflowProcess>.Create([doOwnsValues]);
end;

destructor TMemoryRepository.Destroy;
begin
  FDefinitions.Free;
  inherited;
end;

function TMemoryRepository.GetDefinition(
  const ProcessId: string): TWorkflowProcess;
begin
  TMonitor.Enter(FDefinitions);
  try
    if not FDefinitions.TryGetValue(ProcessId, Result) then
      Result := nil;
  finally
    TMonitor.Exit(FDefinitions);
  end;
end;

function TMemoryRepository.PublishDefinition(const Name: string;
  Process: TWorkflowProcess): string;
begin
  TMonitor.Enter(FDefinitions);
  try
    Result := NewId;
    FDefinitions.Add(Result, Process);
  finally
    TMonitor.Exit(FDefinitions);
  end;
end;

{ TMemoryRuntime }

function TMemoryRuntime.CreateInstance(
  const ProcessId: string): IProcessInstanceData;
begin
  Result := TMemoryInstanceData.Create;
end;

end.

