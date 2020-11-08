unit Octopus.Json.Serializer;

interface

uses
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Bcl.Json.Writer,
  Bcl.Json.Serializer,
  Octopus.Json.Converters,
  Octopus.Process;

type
  TWorkflowSerializer = class
  private
    FWriter: TJsonWriter;
    FConverters: TOctopusJsonConverters;
    FSerializer: TJsonSerializer;
    FProcess: TWorkflowProcess;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;
    class function ProcessToJson(Process: TWorkflowProcess): string;
    procedure WriteProcess(Process: TWorkflowProcess);
    procedure WriteValue(Value: TValue; ValueType: PTypeInfo);
    class function ValueToJson(Value: TValue; ValueType: PTypeInfo): string;
  end;

implementation

{ TWorkflowSerializer }

constructor TWorkflowSerializer.Create(Stream: TStream);
begin
  FWriter := TJsonWriter.Create(Stream);
  FWriter.IndentLength := 2;
  FConverters := TOctopusJsonConverters.Create;
  FConverters.OnGetProcess :=
    function: TWorkflowProcess
    begin
      result := FProcess;
    end;

  FSerializer := TJsonSerializer.Create(FConverters, False);
end;

destructor TWorkflowSerializer.Destroy;
begin
  FWriter.Free;
  FConverters.Free;
  FSerializer.Free;
  inherited;
end;

class function TWorkflowSerializer.ProcessToJson(Process: TWorkflowProcess): string;
var
  stream: TStringStream;
  serializer: TWorkflowSerializer;
begin
  stream := TStringStream.Create;
  try
    serializer := TWorkflowSerializer.Create(stream);
    try
      serializer.WriteProcess(Process);
    finally
      serializer.Free;
    end;
    result := stream.DataString;
  finally
    stream.Free;
  end;
end;

class function TWorkflowSerializer.ValueToJson(Value: TValue; ValueType: PTypeInfo): string;
var
  stream: TStringStream;
  serializer: TWorkflowSerializer;
begin
  stream := TStringStream.Create;
  serializer := TWorkflowSerializer.Create(stream);
  try
    serializer.WriteValue(Value, ValueType);
    result := stream.DataString;
  finally
    stream.Free;
    serializer.Free;
  end;
end;

procedure TWorkflowSerializer.WriteProcess(Process: TWorkflowProcess);
begin
  FProcess := nil;
  FSerializer.Write(Process, FWriter);
  FWriter.Flush;
end;

procedure TWorkflowSerializer.WriteValue(Value: TValue; ValueType: PTypeInfo);
begin
  FSerializer.Write(Value, ValueType, FWriter);
  FWriter.Flush;
end;

end.
