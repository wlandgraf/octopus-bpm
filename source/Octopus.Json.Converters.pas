unit Octopus.Json.Converters;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Generics.Collections,
  Bcl.Json.Converters,
  Bcl.Json.Reader,
  Bcl.Json.Writer,
  Octopus.Json.ObjectConverter,
  Octopus.Process;

type
  TOctopusJsonConverters = class(TJsonConverters)
  private
    FOnGetProcess: TFunc<TWorkflowProcess>;
    procedure SetOnGetProcess(const Value: TFunc<TWorkflowProcess>);
  public
    constructor Create;
    property OnGetProcess: TFunc<TWorkflowProcess> write SetOnGetProcess;
  end;

  TFlowNodeConverterFactory = class(TOctopusConverterFactory)
  public
    function CreateConverter(Converters: TJsonConverters; const ATypeToken: TTypeToken): IJsonTypeConverter; override;
  end;

  TFlowNodeConverter = class(TOctopusObjectConverter)
  public
    constructor Create(AFactory: TOctopusConverterFactory);
  end;

  TVariableConverterFactory = class(TOctopusConverterFactory)
  public
    function CreateConverter(Converters: TJsonConverters; const ATypeToken: TTypeToken): IJsonTypeConverter; override;
  end;

  TVariableConverter = class(TOctopusObjectConverter)
  private
    const
      DefaultValueProp = 'DefaultValue';
  protected
    function ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean; override;
    function WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean; override;
  public
    constructor Create(AFactory: TOctopusConverterFactory);
  end;

//  TInstanceConverterFactory = class(TOctopusConverterFactory)
//  public
//    function CreateConverter(const ATypeToken: TTypeToken): IJsonTypeConverter; override;
//  end;

//  TInstanceConverter = class(TOctopusObjectConverter)
//  private
//    const
//      DataProp = 'Data';
//    procedure ReadInstanceData(AInstance: TProcessInstance; Reader: TJsonReader);
//    procedure WriteInstanceData(AInstance: TProcessInstance; Writer: TJsonWriter);
//  protected
//    function ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean; override;
//    function WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean; override;
//  public
//    constructor Create(AFactory: TOctopusConverterFactory);
//  end;

implementation

uses
  Octopus.Resources;

{ TOctopusJsonConverters }

constructor TOctopusJsonConverters.Create;
begin
  inherited;
  AddFactory(TFlowNodeConverterFactory.Create(Self));
  AddFactory(TVariableConverterFactory.Create(Self));
//  AddFactory(TInstanceConverterFactory.Create(Self));
  AddFactory(TOctopusListConverterFactory.Create(Self));
  AddFactory(TOctopusConverterFactory.Create(Self));
end;

procedure TOctopusJsonConverters.SetOnGetProcess(const Value: TFunc<TWorkflowProcess>);
begin
  FOnGetProcess := Value;
  All(
    procedure(Factory: IJsonConverterFactory)
    begin
      if Factory is TOctopusConverterFactory then
        TOctopusConverterFactory(Factory).OnGetProcess := FOnGetProcess;
    end
  );
end;

{ TVariableConverter }

constructor TVariableConverter.Create(AFactory: TOctopusConverterFactory);
begin
  inherited Create(TVariable, AFactory);
end;

function TVariableConverter.ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean;
var
  variable: TVariable;
  value: TValue;
begin
  if PropName = DefaultValueProp then
  begin
    variable := TVariable(AObject);
    value := TValue.Empty;
    if variable.DataType = nil then
      Reader.ReadNull
    else
      Factory.Converters.Get(variable.DataType.NativeType).ReadJson(Reader, value);
    variable.DefaultValue := value;
    result := true;
  end
  else
    result := inherited;
end;

function TVariableConverter.WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean;
var
  variable: TVariable;
begin
  if PropName = DefaultValueProp then
  begin
    variable := TVariable(AObject);
    if variable.DefaultValue.IsEmpty then
      Writer.WriteNull
    else
      Factory.Converters.Get(variable.DefaultValue.TypeInfo).WriteJson(Writer, variable.DefaultValue);
    result := true;
  end
  else
    result := inherited;
end;

{ TVariableConverterFactory }

function TVariableConverterFactory.CreateConverter(Converters: TJsonConverters;
  const ATypeToken: TTypeToken): IJsonTypeConverter;
begin
  if ATypeToken.IsClass and (ATypeToken.GetClass = TVariable) then
    result := TVariableConverter.Create(Self)
  else
    result := nil;
end;

{ TFlowNodeConverterFactory }

function TFlowNodeConverterFactory.CreateConverter(Converters: TJsonConverters;
  const ATypeToken: TTypeToken): IJsonTypeConverter;
begin
  if ATypeToken.IsClass and ATypeToken.GetClass.InheritsFrom(TFlowNode) then
    result := TFlowNodeConverter.Create(Self)
  else
    result := nil;
end;

{ TFlowNodeConverter }

constructor TFlowNodeConverter.Create(AFactory: TOctopusConverterFactory);
begin
  inherited Create(TFlowNode, AFactory);
  WriteClassType := true;
end;

//{ TInstanceConverterFactory }
//
//function TInstanceConverterFactory.CreateConverter(const ATypeToken: TTypeToken): IJsonTypeConverter;
//begin
//  if ATypeToken.IsClass and (ATypeToken.GetClass = TProcessInstance) then
//    result := TInstanceConverter.Create(Self)
//  else
//    result := nil;
//end;
//
//{ TInstanceConverter }
//
//constructor TInstanceConverter.Create(AFactory: TOctopusConverterFactory);
//begin
//  inherited Create(TProcessInstance, AFactory);
//end;
//
//procedure TInstanceConverter.ReadInstanceData(AInstance: TProcessInstance; Reader: TJsonReader);
//var
//  varName: string;
//  variable: TVariable;
//  value: TValue;
//begin
//  AInstance.Data.Clear;
//  Reader.ReadBeginObject;
//  while Reader.HasNext do
//  begin
//    varName := Reader.ReadName;
//    variable := Factory.GetProcess.GetVariable(varName);
//    if variable = nil then
//      raise Exception.CreateFmt(SErrorVariableNotFound, [varName]);
//
//    value := TValue.Empty;
//    if Reader.Peek = TJsonToken.Null then
//      Reader.ReadNull
//    else
//      Factory.Converters.Get(TTypeToken.FromTypeInfo(variable.DataType.NativeType)).ReadJson(Reader, value);
//
//    AInstance.SetData(varName, value);
//  end;
//  Reader.ReadEndObject;
//end;
//
//function TInstanceConverter.ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean;
//begin
//  if PropName = DataProp then
//  begin
//    ReadInstanceData(TProcessInstance(AObject), Reader);
//    result := true;
//  end
//  else
//    result := inherited;
//end;
//
//procedure TInstanceConverter.WriteInstanceData(AInstance: TProcessInstance; Writer: TJsonWriter);
//var
//  data: TPair<string,TValue>;
//  variable: TVariable;
//begin
//  Writer.WriteBeginObject;
//  for data in AInstance.Data do
//  begin
//    variable := Factory.GetProcess.GetVariable(data.Key);
//    if variable <> nil then
//    begin
//      Writer.WriteName(variable.Name);
//      if (variable.DataType = nil) or data.Value.IsEmpty then
//        Writer.WriteNull
//      else
//        Factory.Converters.Get(TTypeToken.FromTypeInfo(variable.DataType.NativeType)).WriteJson(Writer, data.Value);
//    end;
//  end;
//  Writer.WriteEndObject;
//end;
//
//function TInstanceConverter.WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean;
//begin
//  if PropName = DataProp then
//  begin
//    WriteInstanceData(TProcessInstance(AObject), Writer);
//    result := true;
//  end
//  else
//    result := inherited;
//end;

end.

