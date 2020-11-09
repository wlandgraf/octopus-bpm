unit OctopusTests.Cases.Serialization;

interface

uses
  OctopusTests.TestCase,
  Octopus.Process;

type
  TTestSerialization = class(TOctopusTestCase)
  private
    procedure BuildSampleProcess;
  public
    procedure SetUp; override;
  published
    procedure BasicSerializeProcess;
    procedure BasicDeserializeProcess;
    procedure SerializeProcessCheck;
  end;

  TObjectVar = class
  private
    FInfo: string;
  public
    constructor Create;
    [Persistent]
    property Info: string read FInfo write FInfo;
  end;

implementation

uses
  Generics.Collections,
  System.SysUtils,
  System.Rtti,
  OctopusTests.Utils,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer,
  Octopus.DataTypes;

{ TTestSerialization }

const
  JsonProcess =
    '{' + #13#10 +
    '  "Nodes": [' + #13#10 +
    '    {' + #13#10 +
    '      "Class": "Octopus.Process.Events.TStartEvent",' + #13#10 +
    '      "Id": "start"' + #13#10 +
    '    },' + #13#10 +
    '    {' + #13#10 +
    '      "Class": "Octopus.Process.Events.TEndEvent",' + #13#10 +
    '      "Id": "end"' + #13#10 +
    '    }' + #13#10 +
    '  ],' + #13#10 +
    '  "Transitions": [' + #13#10 +
    '    {' + #13#10 +
    '      "Id": "link",' + #13#10 +
    '      "Source": "start",' + #13#10 +
    '      "Target": "end"' + #13#10 +
    '    }' + #13#10 +
    '  ],' + #13#10 +
    '  "Variables": [' + #13#10 +
    '    {' + #13#10 +
    '      "Name": "Test",' + #13#10 +
    '      "Type": "string",' + #13#10 +
    '      "DefaultValue": "X"' + #13#10 +
    '    }' + #13#10 +
    '  ]' + #13#10 +
    '}';

procedure TTestSerialization.BasicDeserializeProcess;
var
  P: TWorkflowProcess;
begin
  P := TWorkflowDeserializer.ProcessFromJson(JsonProcess);
  try
    CheckEquals(2, P.Nodes.Count);
    CheckEquals(1, P.Transitions.Count);
    CheckEquals('link', P.Transitions[0].Id);
    CheckEquals('start', P.StartNode.Id);
    CheckEquals('end', P.Transitions[0].Target.Id);
  finally
    P.Free;
  end;
end;

procedure TTestSerialization.BasicSerializeProcess;
begin
  Builder
    .Variable('Test', 'X')
    .StartEvent.Id('start')
    .EndEvent.Id('end');
  Process.Transitions[0].Id := 'link';

  CheckEquals(JsonProcess, TWorkflowSerializer.ProcessToJson(Process));
end;

procedure TTestSerialization.BuildSampleProcess;
var
  N: TFlowNode;
begin
  Builder
    .Variable('empty')
    .Variable('str', 'testvar')
    .Variable('int', 12345)
    .Variable('pi', 3.14)
    .Variable('obj', TObjectVar.Create)
    .StartEvent
    .Activity(TTestUtils.PersistedActivity).Get(N)
    .ExclusiveGateway
    .Activity(TTestUtils.PersistedActivity)
    .EndEvent
    .GotoLastGateway
    .LinkTo(N);
end;

procedure TTestSerialization.SerializeProcessCheck;
var
  json: string;
  P: TWorkflowProcess;
  i: integer;
begin
  BuildSampleProcess;

  json := TWorkflowSerializer.ProcessToJson(Process);

  P := TWorkflowDeserializer.ProcessFromJson(json);
  try
    CheckEquals(Process.Variables.Count, P.Variables.Count);
    for i := 0 to Process.Variables.Count - 1 do
      CheckEquals(Process.Variables[i].Name, P.Variables[i].Name);

    CheckEquals(Process.Nodes.Count, P.Nodes.Count);
    for i := 0 to Process.Nodes.Count - 1 do
      CheckEquals(Process.Nodes[i].Id, P.Nodes[i].Id);

    CheckEquals(Process.Transitions.Count, P.Transitions.Count);
    for i := 0 to Process.Transitions.Count - 1 do
    begin
      CheckEquals(Process.Transitions[i].Id, P.Transitions[i].Id);
      CheckEquals(Process.Transitions[i].Source.Id, P.Transitions[i].Source.Id);
      CheckEquals(Process.Transitions[i].Target.Id, P.Transitions[i].Target.Id);
    end;
  finally
    P.Free;
  end;
end;

procedure TTestSerialization.Setup;
var
  OT: TOctopusDataType;
begin
  inherited;
  OT := TOctopusDataType.Create;
  OT.Name := 'ObjectVar';
  OT.NativeType := TypeInfo(TObjectVar);
  TOctopusDataTypes.Default.RegisterType(OT);
end;

{ TObjectVar }

constructor TObjectVar.Create;
begin
  Info := 'Var Content';
end;

initialization
  RegisterOctopusTest(TTestSerialization);
end.

