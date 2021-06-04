unit Octopus.Engine.Variables;

interface

uses
  Rtti, SysUtils, Generics.Collections,
  Octopus.Persistence.Common,
  Octopus.Process;

type
  IMutableVariable = interface(IVariable)
  ['{2733FFC3-DE86-4941-914E-926C09644D78}']
    procedure SetValue(const Value: TValue);
    function GetDirty: Boolean;
    procedure SetDirty(const Value: Boolean);
    property Value: TValue read GetValue write SetValue;
    property Dirty: Boolean read GetDirty write SetDirty;
  end;

  TMutableVariable = class(TInterfacedObject, IMutableVariable)
  strict private
    FName: string;
    FTokenId: string;
    FValue: TValue;
    FDirty: Boolean;
  public
    constructor Create(const AName, ATokenId: string; const AValue: TValue);
    function GetName: string;
    function GetValue: TValue;
    function GetTokenId: string;
    procedure SetValue(const AValue: TValue);
    function GetDirty: Boolean;
    procedure SetDirty(const AValue: Boolean);
  end;

  TContextVariables = class(TInterfacedObject, IVariablesPersistence)
  strict private
    FRuntime: IOctopusInstanceService;
    FVariables: TList<IMutableVariable>;
    FLoaded: Boolean;
    procedure LoadVariables;
    function FindVariable(const Name, TokenId: string): IMutableVariable;
  public
    constructor Create(ARuntime: IOctopusInstanceService);
    destructor Destroy; override;
  public
    { IVariablesPersistence }
    function LoadVariable(const Name: string; const TokenId: string = ''): IVariable;
    procedure SaveVariable(const Name: string; const Value: TValue; const TokenId: string = '');
  end;

implementation

{ TMutableVariable }

constructor TMutableVariable.Create(const AName, ATokenId: string; const AValue: TValue);
begin
  inherited Create;
  FName := AName;
  FTokenId := ATokenId;
  FValue := AValue;
end;

function TMutableVariable.GetDirty: Boolean;
begin
  Result := FDirty;
end;

function TMutableVariable.GetName: string;
begin
  Result := FName;
end;

function TMutableVariable.GetTokenId: string;
begin
  Result := FTokenId;
end;

function TMutableVariable.GetValue: TValue;
begin
  Result := FValue;
end;

procedure TMutableVariable.SetDirty(const AValue: Boolean);
begin
  FDirty := AValue;
end;

procedure TMutableVariable.SetValue(const AValue: TValue);
begin
  FValue := AValue;
  FDirty := True;
end;

{ TContextVariables }

constructor TContextVariables.Create(ARuntime: IOctopusInstanceService);
begin
  inherited Create;
  FRuntime := ARuntime;
  FVariables := TList<IMutableVariable>.Create;
end;

destructor TContextVariables.Destroy;
begin
  FVariables.Free;
  inherited;
end;

function TContextVariables.FindVariable(const Name, TokenId: string): IMutableVariable;
var
  LocalVar: IMutableVariable;
begin
  for LocalVar in FVariables do
    if SameText(LocalVar.Name, Name) and (LocalVar.TokenId = TokenId) then
      Exit(LocalVar);
  Result := nil;
end;

function TContextVariables.LoadVariable(const Name, TokenId: string): IVariable;
begin
  LoadVariables;
  Result := FindVariable(Name, TokenId);
end;

procedure TContextVariables.LoadVariables;
var
  LocalVar: IVariable;
  MutableVar: IMutableVariable;
begin
  if FLoaded then Exit;

  FVariables.Clear;
  for LocalVar in FRuntime.LoadVariables do
  begin
    MutableVar := TMutableVariable.Create(LocalVar.Name, LocalVar.TokenId, LocalVar.Value);
    FVariables.Add(MutableVar);
  end;
  FLoaded := True;
end;

procedure TContextVariables.SaveVariable(const Name: string; const Value: TValue; const TokenId: string);
var
  MutableVar: IMutableVariable;
begin
  LoadVariables;
  MutableVar := FindVariable(Name, TokenId);
  if MutableVar = nil then
  begin
    MutableVar := TMutableVariable.Create(Name, TokenId, Value);
    FVariables.Add(MutableVar);
    MutableVar.Dirty := True;
  end
  else
    MutableVar.Value := Value;

  FRuntime.SaveVariable(Name, Value, TokenId);
end;

end.
