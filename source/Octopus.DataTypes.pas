unit Octopus.DataTypes;

interface

uses
  Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  System.Rtti;

type
  TOctopusDataType = class
  private
    FName: string;
    FNativeType: PTypeInfo;
  public
    constructor Create(const AName: string; ANativeType: PTypeInfo);
    property Name: string read FName write FName;
    property NativeType: PTypeInfo read FNativeType write FNativeType;
  end;

  TOctopusDataTypes = class
  strict private
    class var
      FDefault: TOctopusDataTypes;
  private
    FRegisteredTypes: TObjectDictionary<string, TOctopusDataType>;
    function NativeTypeName(AType: PTypeInfo): string;
    procedure RegisterDefaultDataTypes;
  public
    class function Default: TOctopusDataTypes;
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterType(const Name: string; TypeInfo: PTypeInfo);
    function Find(const Name: string): TOctopusDataType; overload;
    function Find(NativeType: PTypeInfo): TOctopusDataType; overload;
    function Get(const Name: string): TOctopusDataType; overload;
    function Get(NativeType: PTypeInfo): TOctopusDataType; overload;
  end;

implementation

uses
  Octopus.Exceptions,
  Octopus.Resources;

{ TOctopusDataTypes }

constructor TOctopusDataTypes.Create;
begin
  inherited Create;
  FRegisteredTypes := TObjectDictionary<string,TOctopusDataType>.Create([doOwnsValues]);
  RegisterDefaultDataTypes;
end;

class function TOctopusDataTypes.Default: TOctopusDataTypes;
begin
  if FDefault = nil then
    FDefault := TOctopusDataTypes.Create;
  result := FDefault;
end;

destructor TOctopusDataTypes.Destroy;
begin
  FRegisteredTypes.Free;
  inherited;
end;

function TOctopusDataTypes.Find(const Name: string): TOctopusDataType;
begin
  FRegisteredTypes.TryGetValue(Name, result);
end;

function TOctopusDataTypes.Find(NativeType: PTypeInfo): TOctopusDataType;
var
  T: TOctopusDataType;
begin
  for T in FRegisteredTypes.Values do
    if T.NativeType = NativeType then
      exit(T);
  result := nil;
end;

function TOctopusDataTypes.Get(const Name: string): TOctopusDataType;
begin
  result := Find(Name);
  if result = nil then
    raise Exception.CreateFmt(SErrorUnsupportedDataType, [Name]);
end;

function TOctopusDataTypes.Get(NativeType: PTypeInfo): TOctopusDataType;
begin
  result := Find(NativeType);
  if result = nil then
    raise EOctopusException.CreateFmt(SErrorUnsupportedDataType, [NativeTypeName(NativeType)]);
end;

function TOctopusDataTypes.NativeTypeName(AType: PTypeInfo): string;
var
  context: TRttiContext;
begin
  context := TRttiContext.Create;
  try
    if AType = nil then
      Result := 'unknown'
    else
      Result := context.GetType(AType).QualifiedName;
  finally
    context.Free;
  end;
end;

procedure TOctopusDataTypes.RegisterDefaultDataTypes;
begin
  RegisterType('System.string', TypeInfo(string));
  RegisterType('System.Integer', TypeInfo(Integer));
  RegisterType('System.Boolean', TypeInfo(Boolean));
  RegisterType('System.Double', TypeInfo(Double));
  RegisterType('System.Extended', TypeInfo(Extended));
  RegisterType('System.Int64', TypeInfo(Int64));
  RegisterType('System.Byte', TypeInfo(Byte));
  RegisterType('System.TDateTime', TypeInfo(TDateTime));
  RegisterType('System.TDate', TypeInfo(TDate));
  RegisterType('System.TTime', TypeInfo(TTime));
  RegisterType('System.TArray<System.string>', TypeInfo(TArray<string>));
  RegisterType('System.TArray<System.Integer>', TypeInfo(TArray<Integer>));
  RegisterType('System.TArray<System.Boolean>', TypeInfo(TArray<Boolean>));
  RegisterType('System.TArray<System.Double>', TypeInfo(TArray<Double>));
  RegisterType('System.TArray<System.Byte>', TypeInfo(TArray<Byte>));
end;

procedure TOctopusDataTypes.RegisterType(const Name: string;
  TypeInfo: PTypeInfo);
begin
  FRegisteredTypes.AddOrSetValue(Name, TOctopusDataType.Create(Name, TypeInfo));
end;

class destructor TOctopusDataTypes.Destroy;
begin
  if FDefault <> nil then
    FDefault.Free;
end;

{ TOctopusDataType }

constructor TOctopusDataType.Create(const AName: string;
  ANativeType: PTypeInfo);
begin
  inherited Create;
  FName := AName;
  FNativeType := ANativeType;
end;

end.

