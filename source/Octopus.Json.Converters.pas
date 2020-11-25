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

  TConditionConverterFactory = class(TOctopusConverterFactory)
  public
    function CreateConverter(Converters: TJsonConverters; const ATypeToken: TTypeToken): IJsonTypeConverter; override;
  end;

  TConditionConverter = class(TOctopusObjectConverter)
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
      ValuePropName = 'Value';
  protected
    function ReadProperty(const PropName: string; AObject: TObject; Reader: TJsonReader): boolean; override;
    function WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean; override;
  public
    constructor Create(AFactory: TOctopusConverterFactory);
  end;

implementation

uses
  Octopus.Resources;

{ TOctopusJsonConverters }

constructor TOctopusJsonConverters.Create;
begin
  inherited;
  AddFactory(TFlowNodeConverterFactory.Create(Self));
  AddFactory(TConditionConverterFactory.Create(Self));
  AddFactory(TVariableConverterFactory.Create(Self));
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
  if PropName = ValuePropName then
  begin
    variable := TVariable(AObject);
    value := TValue.Empty;
    if variable.DataType = nil then
      Reader.ReadNull
    else
      Factory.Converters.Get(variable.DataType.NativeType).ReadJson(Reader, value);
    variable.Value := value;
    result := true;
  end
  else
    result := inherited;
end;

function TVariableConverter.WriteProperty(const PropName: string; AObject: TObject; Writer: TJsonWriter): boolean;
var
  variable: TVariable;
begin
  if PropName = ValuePropName then
  begin
    variable := TVariable(AObject);
    if variable.Value.IsEmpty then
      Writer.WriteNull
    else
      Factory.Converters.Get(variable.Value.TypeInfo).WriteJson(Writer, variable.Value);
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

{ TConditionConverterFactory }

function TConditionConverterFactory.CreateConverter(Converters: TJsonConverters;
  const ATypeToken: TTypeToken): IJsonTypeConverter;
begin
  if ATypeToken.IsClass and ATypeToken.GetClass.InheritsFrom(TCondition) then
    result := TConditionConverter.Create(Self)
  else
    result := nil;
end;

{ TConditionConverter }

constructor TConditionConverter.Create(AFactory: TOctopusConverterFactory);
begin
  inherited Create(TCondition, AFactory);
  WriteClassType := true;
end;

end.

