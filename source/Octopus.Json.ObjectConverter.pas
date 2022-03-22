unit Octopus.Json.ObjectConverter;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Generics.Collections,
  Bcl.Collections,
  Bcl.Json.Converters,
  Bcl.Json.Reader,
  Bcl.Json.Writer,
  Bcl.Rtti.ObjectFactory,
  Octopus.Process;

type
  TOctopusConverterFactory = class;

  TOctopusObjectConverter = class(TInterfacedObject, IJsonTypeConverter)
  private
    FClass: TClass;
    FFactory: TOctopusConverterFactory;
    FContext: TRttiContext;
    FWriteClassType: boolean;
    const
      OctopusJsonClassProp = 'Class';
    function FindType(const AQualifiedName: string): TClass;
    function GetPropName(const AName: string): string;
    function IsPersistent(Attributes: TArray<TCustomAttribute>; var APropName: string): boolean;
    function CreateInstance(AType: TClass): TObject;
    function ReadObject(Reader: TJsonReader; Target: TObject): TObject;
    procedure ReadProperties(Reader: TJsonReader; var Target: TObject);
    function ReadElementId(Reader: TJsonReader): TFlowElement;
    procedure WriteObject(Writer: TJsonWriter; const AObject: TObject);
    procedure WriteProperties(AObject: TObject; Writer: TJsonWriter);
    procedure WriteElementId(Writer: TJsonWriter; Element: TFlowElement);
  protected
    function GetProcessElement(const AId: string): TFlowElement;
    function ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean; virtual;
    function WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean; virtual;
    property Context: TRttiContext read FContext;
    property Factory: TOctopusConverterFactory read FFactory;
    property WriteClassType: boolean read FWriteClassType write FWriteClassType;
  public
    constructor Create(AClass: TClass; AFactory: TOctopusConverterFactory);
    destructor Destroy; override;
    procedure WriteJson(const Writer: TJsonWriter; const Value: TValue);
    procedure ReadJson(const Reader: TJsonReader; var Value: TValue);
    function ShouldWrite(const Value: TValue; const Mode: TInclusionMode): Boolean;
  end;

  TOctopusConverterFactory = class(TInterfacedObject, IJsonConverterFactory)
  private
    FConverters: TJsonConverters;
    FObjectFactory: IObjectFactory;
    FOnGetProcess: TFunc<TWorkflowProcess>;
  protected
    property ObjectFactory: IObjectFactory read FObjectFactory;
  public
    constructor Create(AConverters: TJsonConverters);
    function CreateConverter(Converters: TJsonConverters; const ATypeToken: TTypeToken): IJsonTypeConverter; virtual;
    function GetProcess: TWorkflowProcess;
    property Converters: TJsonConverters read FConverters;
    property OnGetProcess: TFunc<TWorkflowProcess> read FOnGetProcess write FOnGetProcess;
  end;

  TOctopusListConverter = class(TInterfacedObject, IJsonTypeConverter)
  private
    FClass: TClass;
    FFactory: TOctopusConverterFactory;
    FItemConverter: IJsonTypeConverter;
    procedure ReadList(Reader: TJsonReader; List: IObjectList);
  public
    constructor Create(const AClass: TClass; const AItemTypeToken: TTypeToken; AFactory: TOctopusConverterFactory);
    procedure WriteJson(const Writer: TJsonWriter; const Value: TValue);
    procedure ReadJson(const Reader: TJsonReader; var Value: TValue);
    function ShouldWrite(const Value: TValue; const Mode: TInclusionMode): Boolean;
  end;

  TOctopusListConverterFactory = class(TOctopusConverterFactory)
  public
    function CreateConverter(Converters: TJsonConverters; const ATypeToken: TTypeToken): IJsonTypeConverter; override;
  end;

implementation

uses
  Bcl.Rtti.Utils,
  Octopus.Exceptions,
  Octopus.Resources;

{ TOctopusObjectConverter }

constructor TOctopusObjectConverter.Create(AClass: TClass; AFactory: TOctopusConverterFactory);
begin
  FContext := TRttiContext.Create;
  FClass := AClass;
  FFactory := AFactory;
  FWriteClassType := false;
end;

function TOctopusObjectConverter.CreateInstance(AType: TClass): TObject;
begin
  result := FFactory.ObjectFactory.CreateInstance(AType);
end;

destructor TOctopusObjectConverter.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TOctopusObjectConverter.FindType(const AQualifiedName: string): TClass;
var
  RttiType: TRttiType;
begin
  RttiType := FContext.FindType(AQualifiedName);
  if (RttiType <> nil) and RttiType.IsInstance then
    Result := RttiType.AsInstance.MetaclassType
  else
    result := nil;
end;

function TOctopusObjectConverter.GetProcessElement(const AId: string): TFlowElement;
begin
  result := Factory.GetProcess.FindNode(AId);
  if result = nil then
    result := Factory.GetProcess.FindTransition(AId);
  if result = nil then
    raise EOctopusElementNotFound.Create(AId);
end;

function TOctopusObjectConverter.GetPropName(const AName: string): string;
begin
  if (Length(AName) > 0) and (AName[1] = 'F') then
    Result := Copy(AName, 2, MaxInt)
  else
    Result := AName;
end;

function TOctopusObjectConverter.IsPersistent(Attributes: TArray<TCustomAttribute>; var APropName: string): boolean;
var
  A: TCustomAttribute;
begin
  for A in Attributes do
    if A is Persistent then
    begin
      if Persistent(A).PropName <> '' then
        APropName := Persistent(A).PropName;
      exit(true);
    end;
  result := false;
end;

function TOctopusObjectConverter.ReadElementId(Reader: TJsonReader): TFlowElement;
begin
  if Reader.Peek = TJsonToken.Null then
  begin
    Reader.ReadNull;
    result := nil;
  end
  else
    result := GetProcessElement(Reader.ReadString);
end;

procedure TOctopusObjectConverter.ReadJson(const Reader: TJsonReader; var Value: TValue);
begin
  Value := ReadObject(Reader, Value.AsObject);
end;

function TOctopusObjectConverter.ReadObject(Reader: TJsonReader; Target: TObject): TObject;
begin
  if Reader.Peek = TJsonToken.Null then
  begin
    Reader.ReadNull;
    exit(nil);
  end;

  Reader.ReadBeginObject;
  ReadProperties(Reader, Target);
  Reader.ReadEndObject;

  Result := Target;
end;

procedure TOctopusObjectConverter.ReadProperties(Reader: TJsonReader; var Target: TObject);
var
  propId, targetTypeName: string;
  targetClass: TClass;
begin
  while Reader.HasNext do
  begin
    propId := Reader.ReadName;

    if propId = OctopusJsonClassProp then // class identification property (entity type)
    begin
      targetTypeName := Reader.ReadString;
      targetClass := FindType(targetTypeName);
      if targetClass = nil then
        raise Exception.CreateFmt(SErrorJsonTypeNotFound, [targetTypeName]);

      if Target = nil then
      begin
        if not targetClass.InheritsFrom(FClass) then
          raise Exception.CreateFmt(SErrorJsonInvalidInstanceType, [OctopusJsonClassProp, targetClass.QualifiedClassName, FClass.QualifiedClassName]);
        Target := CreateInstance(targetClass);
      end
      else
      begin
        if Target.ClassType <> targetClass then
          raise Exception.CreateFmt(SErrorJsonInvalidInstanceType, [OctopusJsonClassProp, targetClass.QualifiedClassName, target.QualifiedClassName]);
      end;
    end
    else // regular properties
    begin
      if Target = nil then
        Target := CreateInstance(FClass);

      if not ReadProperty(PropId, Target, Reader) then
        raise Exception.CreateFmt(SErrorJsonInvalidProperty, [PropId, Target.QualifiedClassName]);
    end;
  end;
end;

function TOctopusObjectConverter.ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean;

  function ReadMember(AType: TRttiType; var AValue: TValue): boolean;
  var
    oldObject: TObject;
  begin
    if AType.IsInstance then
    begin
      oldObject := AValue.AsObject;
      if AType.IsInstance and AType.AsInstance.MetaclassType.InheritsFrom(TFlowElement) then
        AValue := ReadElementId(Reader) // reference to TFlowElement object
      else
        FFactory.Converters.Get(AType.Handle).ReadJson(Reader, AValue);
      result := oldObject <> AValue.AsObject;
    end
    else
    begin
      AValue := TValue.Empty;
      FFactory.Converters.Get(AType.Handle).ReadJson(Reader, AValue);
      result := true;
    end;
  end;

var
  ClassType: TRttiType;
  RttiProp: TRttiProperty;
  RttiField: TRttiField;
  value: TValue;
  targetPropName: string;
begin
  Result := False;
  ClassType := FContext.GetType(AObject.ClassType);

  for RttiProp in ClassType.GetProperties do
  begin
    targetPropName := RttiProp.Name;
    if IsPersistent(RttiProp.GetAttributes, targetPropName) and (PropName = targetPropName) and (RttiProp.PropertyType <> nil) then
    begin
      value := RttiProp.GetValue(AObject);
      if ReadMember(RttiProp.PropertyType, value) then
        RttiProp.SetValue(AObject, value);
      exit(true);
    end;
  end;

  for RttiField in ClassType.GetFields do
  begin
    targetPropName := GetPropName(RttiField.Name);
    if IsPersistent(RttiField.GetAttributes, targetPropName) and (PropName = targetPropName) and (RttiField.FieldType <> nil) then
    begin
      value := RttiField.GetValue(AObject);
      if ReadMember(RttiField.FieldType, value) then
        RttiField.SetValue(AObject, value);
      exit(true);
    end;
  end;
end;

function TOctopusObjectConverter.ShouldWrite(const Value: TValue; const Mode: TInclusionMode): Boolean;
begin
  if Mode = TInclusionMode.Always then Exit(True);
  Result := Value.AsObject <> nil;
end;

procedure TOctopusObjectConverter.WriteElementId(Writer: TJsonWriter; Element: TFlowElement);
begin
  if Element = nil then
    Writer.WriteNull
  else
    Writer.WriteString(Element.Id);
end;

procedure TOctopusObjectConverter.WriteJson(const Writer: TJsonWriter; const Value: TValue);
begin
  WriteObject(Writer, Value.AsObject);
end;

procedure TOctopusObjectConverter.WriteObject(Writer: TJsonWriter; const AObject: TObject);
begin
  if AObject = nil then
  begin
    Writer.WriteNull;
    exit;
  end;

  Writer.WriteBeginObject;

  if WriteClassType then
    Writer.WriteName(OctopusJsonClassProp).WriteString(AObject.ClassType.QualifiedClassName);

  WriteProperties(AObject, Writer);
  Writer.WriteEndObject;
end;

procedure TOctopusObjectConverter.WriteProperties(AObject: TObject; Writer: TJsonWriter);

  procedure WriteMember(AName: string; AType: TRttiType; AValue: TValue);
  begin
    // do not serialize nil objects
    if AType.IsInstance and AValue.IsEmpty then Exit;

    Writer.WriteName(AName);
    if not WriteProperty(AName, AObject, Writer) then
    begin
      if AType.IsInstance and AType.AsInstance.MetaclassType.InheritsFrom(TFlowElement) then
        WriteElementId(Writer, AValue.AsType<TFlowElement>) // reference to TFlowElement object
      else
        FFactory.Converters.Get(AType.Handle).WriteJson(Writer, AValue);
    end;
  end;

var
  ClassType: TRttiType;
  RttiProp: TRttiProperty;
  RttiField: TRttiField;
  propName: string;
begin
  ClassType := FContext.GetType(AObject.ClassType);

  for RttiProp in ClassType.GetProperties do
  begin
    propName := RttiProp.Name;
    if (RttiProp.PropertyType <> nil) and IsPersistent(RttiProp.GetAttributes, propName) and RttiProp.IsReadable and RttiProp.IsWritable then
      WriteMember(propName, RttiProp.PropertyType, RttiProp.GetValue(AObject));
  end;

  for RttiField in ClassType.GetFields do
  begin
    propName := GetPropName(RttiField.Name);
    if (RttiField.FieldType <> nil) and IsPersistent(RttiField.GetAttributes, propName) then
      WriteMember(propName, RttiField.FieldType, RttiField.GetValue(AObject));
  end;
end;

function TOctopusObjectConverter.WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean;
begin
  result := false;
end;

{ TOctopusListConverter }

constructor TOctopusListConverter.Create(const AClass: TClass; const AItemTypeToken: TTypeToken; AFactory: TOctopusConverterFactory);
begin
  FClass := AClass;
  FFactory := AFactory;
  FItemConverter := FFactory.Converters.Get(AItemTypeToken);
end;

procedure TOctopusListConverter.ReadJson(const Reader: TJsonReader; var Value: TValue);
var
  created: boolean;
  target: TObject;
begin
  target := Value.AsObject;
  created := False;
  if target = nil then
  begin
    target := FFactory.ObjectFactory.CreateInstance(FClass);
    created := true;
  end;
  try
    ReadList(Reader, AsObjectList(Target));
  except
    if created then
      target.Free;
    raise;
  end;
  Value := target;
end;

procedure TOctopusListConverter.ReadList(Reader: TJsonReader; List: IObjectList);
var
  Value: TValue;
begin
  List.Clear;
  Reader.ReadBeginArray;
  while Reader.HasNext do
  begin
    Value := TValue.Empty;
    FItemConverter.ReadJson(Reader, Value);
    List.Add(Value.AsObject);
  end;
  Reader.ReadEndArray;
end;

function TOctopusListConverter.ShouldWrite(const Value: TValue; const Mode: TInclusionMode): Boolean;
begin
  if Mode = TInclusionMode.Always then Exit(True);
  Result := Value.AsObject <> nil;
  // Todo: avoid serializing when list is empty as well
end;

procedure TOctopusListConverter.WriteJson(const Writer: TJsonWriter; const Value: TValue);
var
  list: IObjectList;
  i: integer;
  item: TObject;
begin
  Writer.WriteBeginArray;
  if not Value.IsEmpty then
  begin
    list := AsObjectList(Value.AsObject);
    if list <> nil then
      for i := 0 to list.Count - 1 do
      begin
        item := list.Item(i);
        if item = nil then
          Writer.WriteNull
        else
          FFactory.Converters.Get(item.ClassType).WriteJson(Writer, item);
      end;
  end;
  Writer.WriteEndArray;
end;

{ TOctopusConverterFactory }

constructor TOctopusConverterFactory.Create(AConverters: TJsonConverters);
begin
  FConverters := AConverters;
  FObjectFactory := TObjectFactory.Create;
end;

function TOctopusConverterFactory.CreateConverter(Converters: TJsonConverters;
  const ATypeToken: TTypeToken): IJsonTypeConverter;
begin
  if ATypeToken.IsClass then
    result := TOctopusObjectConverter.Create(ATypeToken.GetClass, Self)
  else
    result := nil;
end;

function TOctopusConverterFactory.GetProcess: TWorkflowProcess;
begin
  if Assigned(FOnGetProcess) then
    result := FOnGetProcess
  else
    result := nil;
  if result = nil then
    raise Exception.Create(SErrorProcessNotAssigned);
end;

{ TOctopusListConverterFactory }

function TOctopusListConverterFactory.CreateConverter(Converters: TJsonConverters;
  const ATypeToken: TTypeToken): IJsonTypeConverter;
begin
  if ATypeToken.IsClass and IsObjectList(ATypeToken.GetClass) then
    result := TOctopusListConverter.Create(ATypeToken.GetClass, TRttiUtils.GetInstance.GetSurroundedClass(ATypeToken.GetClass), Self)
  else
    result := nil;
end;

end.

