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
    class function ProcessFromJson(Json: string): TWorkflowProcess;
    //class function InstanceFromJson(Json: string; Process: TWorkflowProcess): TProcessInstance;
    function ReadProcess: TWorkflowProcess;
    //function ReadInstance(Process: TWorkflowProcess): TProcessInstance;
    function ReadValue(ValueType: PTypeInfo): TValue;
    class function ValueFromJson(Json: string; ValueType: PTypeInfo): TValue;
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

  FDeserializer := TJsonDeserializer.Create(FReader, FConverters);
  FDeserializer.OnObjectCreated :=
    procedure(Obj: TObject)
    begin
      if Obj is TWorkflowProcess then
        FProcess := TWorkflowProcess(Obj);
    end;
end;

destructor TWorkflowDeserializer.Destroy;
begin
  FReader.Free;
  FConverters.Free;
  FDeserializer.Free;
  inherited;
end;

//class function TWorkflowDeserializer.InstanceFromJson(Json: string; Process: TWorkflowProcess): TProcessInstance;
//var
//  stream: TStringStream;
//  deserializer: TWorkflowDeserializer;
//begin
//  stream := TStringStream.Create(Json);
//  deserializer := TWorkflowDeserializer.Create(stream);
//  try
//    result := deserializer.ReadInstance(Process);
//  finally
//    stream.Free;
//    deserializer.Free;
//  end;
//end;

class function TWorkflowDeserializer.ProcessFromJson(Json: string): TWorkflowProcess;
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

//function TWorkflowDeserializer.ReadInstance(Process: TWorkflowProcess): TProcessInstance;
//begin
//  FProcess := Process;
//  result := FDeserializer.Read<TProcessInstance>;
//end;

function TWorkflowDeserializer.ReadProcess: TWorkflowProcess;
begin
  FProcess := nil;
  result := FDeserializer.Read<TWorkflowProcess>;
end;

function TWorkflowDeserializer.ReadValue(ValueType: PTypeInfo): TValue;
begin
  result := TValue.Empty;
  FDeserializer.Read(result, ValueType);
end;

class function TWorkflowDeserializer.ValueFromJson(Json: string; ValueType: PTypeInfo): TValue;
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

