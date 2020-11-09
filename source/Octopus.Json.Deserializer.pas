unit Octopus.Json.Deserializer;

interface

uses
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Bcl.Json.Reader,
  Bcl.Json.Deserializer,
  Octopus.Json.Converters,
  Octopus.Process;

type
  TWorkflowDeserializer = class
  private
    FReader: TJsonReader;
    FConverters: TOctopusJsonConverters;
    FDeserializer: TJsonDeserializer;
    FProcess: TWorkflowProcess;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;
    class function ProcessFromJson(const Json: string): TWorkflowProcess;
    function ReadProcess: TWorkflowProcess;
    function ReadValue(ValueType: PTypeInfo): TValue;
    class function ValueFromJson(const Json: string; ValueType: PTypeInfo): TValue;
  end;

implementation

{ TWorkflowDeserializer }

constructor TWorkflowDeserializer.Create(Stream: TStream);
begin
  FReader := TJsonReader.Create(Stream);

  FConverters := TOctopusJsonConverters.Create;
  FConverters.OnGetProcess :=
    function: TWorkflowProcess
    begin
      result := FProcess;
    end;

  FDeserializer := TJsonDeserializer.Create(FConverters, False);
end;

destructor TWorkflowDeserializer.Destroy;
begin
  FReader.Free;
  FConverters.Free;
  FDeserializer.Free;
  inherited;
end;

class function TWorkflowDeserializer.ProcessFromJson(const Json: string): TWorkflowProcess;
var
  stream: TStringStream;
  deserializer: TWorkflowDeserializer;
begin
  stream := TStringStream.Create(Json);
  deserializer := TWorkflowDeserializer.Create(stream);
  try
    result := deserializer.ReadProcess;
  finally
    stream.Free;
    deserializer.Free;
  end;
end;

function TWorkflowDeserializer.ReadProcess: TWorkflowProcess;
var
  TempProcess: TValue;
begin
  FProcess := TWorkflowProcess.Create;
  try
    TempProcess := FProcess;
    FDeserializer.Read(FReader, TempProcess, TWorkflowProcess);
    Result := FProcess;
  except
    FProcess.Free;
    raise;
  end;
end;

function TWorkflowDeserializer.ReadValue(ValueType: PTypeInfo): TValue;
begin
  Result := TValue.Empty;
  FDeserializer.Read(FReader, Result, ValueType);
end;

class function TWorkflowDeserializer.ValueFromJson(const Json: string; ValueType: PTypeInfo): TValue;
var
  stream: TStringStream;
  deserializer: TWorkflowDeserializer;
begin
  stream := TStringStream.Create(Json);
  deserializer := TWorkflowDeserializer.Create(stream);
  try
    result := deserializer.ReadValue(ValueType);
  finally
    stream.Free;
    deserializer.Free;
  end;
end;

end.

