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
    procedure RegisterType(DataType: TOctopusDataType);
    function Find(const Name: string): TOctopusDataType; overload;
    function Find(NativeType: PTypeInfo): TOctopusDataType; overload;
    function Get(const Name: string): TOctopusDataType; overload;
    function Get(NativeType: PTypeInfo): TOctopusDataType; overload;
  end;

  TOctopusString = class(TOctopusDataType)
  public
    constructor Create;
  end;

  TOctopusInteger = class(TOctopusDataType)
  public
    constructor Create;
  end;

  TOctopusBoolean = class(TOctopusDataType)
  public
    constructor Create;
  end;

  TOctopusDouble = class(TOctopusDataType)
  public
    constructor Create;
  end;

  TOctopusExtended = class(TOctopusDataType)
  public
    constructor Create;
  end;

implementation

uses
  Octopus.Resources;

{ TOctopusDataTypes }

constructor TOctopusDataTypes.Create;
begin
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
    raise Exception.CreateFmt(SErrorUnsupportedDataType, [NativeTypeName(NativeType)]);
end;

function TOctopusDataTypes.NativeTypeName(AType: PTypeInfo): string;
var
  context: TRttiContext;
begin
  context := TRttiContext.Create;
  try
    result := context.GetType(AType).QualifiedName;
  finally
    context.Free;
  end;
end;

procedure TOctopusDataTypes.RegisterDefaultDataTypes;
begin
  RegisterType(TOctopusString.Create);
  RegisterType(TOctopusInteger.Create);
  RegisterType(TOctopusBoolean.Create);
  RegisterType(TOctopusDouble.Create);
  RegisterType(TOctopusExtended.Create);
end;

procedure TOctopusDataTypes.RegisterType(DataType: TOctopusDataType);
begin
  FRegisteredTypes.AddOrSetValue(DataType.Name, DataType);
end;

class destructor TOctopusDataTypes.Destroy;
begin
  if FDefault <> nil then
    FDefault.Free;
end;

{ TOctopusString }

constructor TOctopusString.Create;
begin
  inherited Create;
  Name := 'string';
  NativeType := TypeInfo(string);
end;

{ TOctopusInteger }

constructor TOctopusInteger.Create;
begin
  inherited Create;
  Name := 'integer';
  NativeType := TypeInfo(integer);
end;

{ TOctopusBoolean }

constructor TOctopusBoolean.Create;
begin
  inherited Create;
  Name := 'boolean';
  NativeType := TypeInfo(boolean);
end;

{ TOctopusDouble }

constructor TOctopusDouble.Create;
begin
  inherited Create;
  Name := 'double';
  NativeType := TypeInfo(double);
end;

{ TOctopusExtended }

constructor TOctopusExtended.Create;
begin
  inherited Create;
  Name := 'extended';
  NativeType := TypeInfo(extended);
end;

end.

