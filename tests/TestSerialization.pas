unit TestSerialization;

interface

uses
  DUnitX.TestFramework,
  OctopusTestCase,
  Octopus.Process;

type
  [TestFixture]
  TTestSerialization = class(TOctopusTestCase)
  private
    procedure BuildSampleProcess;
  public
    [Setup]
    procedure Setup; override;
    [Test] procedure BasicSerializeProcess;
    [Test] procedure BasicDeserializeProcess;
    //[Test] procedure BasicSerializeInstance;
    //[Test] procedure BasicDeserializeInstance;
    [Test] procedure SerializeProcessCheck;
    //[Test] procedure SerializeInstanceCheck;
    //[Test] procedure SerializeInstanceRun;
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
  OctopusTestUtils,
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

//  JsonInstance =
//    '{' + #13#10 +
//    '  "Status": "Finished",' + #13#10 +
//    '  "Tokens": [],' + #13#10 +
//    '  "Checked": true,' + #13#10 +
//    '  "Data": {' + #13#10 +
//    '    "Test": "X"' + #13#10 +
//    '  }' + #13#10 +
//    '}';

//procedure TTestSerialization.BasicDeserializeInstance;
//var
//  P: TWorkflowProcess;
//  I: TProcessInstance;
//begin
//  P := TWorkflowDeserializer.ProcessFromJson(JsonProcess);
//  I := TWorkflowDeserializer.InstanceFromJson(JsonInstance, P);
//  try
//    Assert.AreEqual(TInstanceStatus.Finished, I.Status);
//    Assert.AreEqual(0, I.Tokens.Count);
//    Assert.IsTrue(I.Checked);
//    Assert.AreEqual('X', I.GetData('Test').AsString);
//  finally
//    P.Free;
//    I.Free;
//  end;
//end;

procedure TTestSerialization.BasicDeserializeProcess;
var
  P: TWorkflowProcess;
begin
  P := TWorkflowDeserializer.ProcessFromJson(JsonProcess);
  try
    Assert.AreEqual(2, P.Nodes.Count);
    Assert.AreEqual(1, P.Transitions.Count);
    Assert.AreEqual('link', P.Transitions[0].Id);
    Assert.AreEqual('start', P.StartNode.Id);
    Assert.AreEqual('end', P.Transitions[0].Target.Id);
  finally
    P.Free;
  end;
end;

//procedure TTestSerialization.BasicSerializeInstance;
//var
//  instance: TProcessInstance;
//  json: string;
//begin
//  Builder
//    .Variable('Test', 'X')
//    .StartEvent
//    .EndEvent;
//
//  instance := TProcessInstance.Create;
//  try
//    RunInstance(instance);
//    json := TWorkflowSerializer.InstanceToJson(instance, Process);
//    Assert.AreEqual(JsonInstance, json);
//  finally
//    instance.Free;
//  end;
//end;

procedure TTestSerialization.BasicSerializeProcess;
begin
  Builder
    .Variable('Test', 'X')
    .StartEvent.Id('start')
    .EndEvent.Id('end');
  Process.Transitions[0].Id := 'link';

  Assert.AreEqual(JsonProcess, TWorkflowSerializer.ProcessToJson(Process));
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
    Assert.AreEqual(Process.Variables.Count, P.Variables.Count);
    for i := 0 to Process.Variables.Count - 1 do
      Assert.AreEqual(Process.Variables[i].Name, P.Variables[i].Name);

    Assert.AreEqual(Process.Nodes.Count, P.Nodes.Count);
    for i := 0 to Process.Nodes.Count - 1 do
      Assert.AreEqual(Process.Nodes[i].Id, P.Nodes[i].Id);

    Assert.AreEqual(Process.Transitions.Count, P.Transitions.Count);
    for i := 0 to Process.Transitions.Count - 1 do
    begin
      Assert.AreEqual(Process.Transitions[i].Id, P.Transitions[i].Id);
      Assert.AreEqual(Process.Transitions[i].Source.Id, P.Transitions[i].Source.Id);
      Assert.AreEqual(Process.Transitions[i].Target.Id, P.Transitions[i].Target.Id);
    end;
  finally
    P.Free;
  end;
end;

//procedure TTestSerialization.SerializeInstanceCheck;
//var
//  I1, I2: TProcessInstance;
//  json: string;
//  D: TPair<string,TValue>;
//begin
//  BuildSampleProcess;
//
//  I1 := TProcessInstance.Create;
//  try
//    RunInstance(I1);
//    json := TWorkflowSerializer.InstanceToJson(I1, Process);
//
//    I2 := TWorkflowDeserializer.InstanceFromJson(json, Process);
//    try
//      Assert.AreEqual(I1.Status, I2.Status);
//      Assert.AreEqual(I1.Checked, I2.Checked);
//
//      Assert.AreEqual(I1.Tokens.Count, I2.Tokens.Count);
//      //for i := 0 to I1.Tokens.Count - 1 do
//      //  Assert.AreEqual(I1.Tokens[i].Transition.Id, I2.Tokens[i].Transition.Id);
//
//      Assert.AreEqual(I1.Data.Count, I2.Data.Count);
//      for D in I1.Data do
//      begin
//        Assert.IsTrue(I2.Data.ContainsKey(D.Key));
//        if not D.Value.IsObject then
//          Assert.AreEqual(D.Value.ToString, I2.Data[D.Key].ToString);
//      end;
//    finally
//      I2.Free;
//    end;
//  finally
//    I1.Free;
//  end;
//end;

//procedure TTestSerialization.SerializeInstanceRun;
//var
//  instance: TProcessInstance;
//  json: string;
//  A: TActivity;
//begin
//  Builder
//    .StartEvent
//    .ParallelGateway.Id('stop')
//    .Activity(TTestUtils.PersistedActivity).Get(A)
//    .EndEvent
//    .GotoElement(A)
//    .LinkTo('stop');
//
//  instance := TProcessInstance.Create;
//  try
//    json := TWorkflowSerializer.InstanceToJson(instance, Process);
//    instance.Free;
//
//    instance := TWorkflowDeserializer.InstanceFromJson(json, Process);
//    Assert.AreEqual(TInstanceStatus.New, instance.Status);
//    Assert.AreEqual(0, instance.Tokens.Count);
//
//    RunInstance(instance);
//    json := TWorkflowSerializer.InstanceToJson(instance, Process);
//    instance.Free;
//
//    instance := TWorkflowDeserializer.InstanceFromJson(json, Process);
//    Assert.AreEqual(TInstanceStatus.Running, instance.Status);
//    Assert.AreEqual(1, instance.Tokens.Count);
//    Assert.AreEqual('stop', instance.Tokens[0].Transition.Target.Id);
//  finally
//    instance.Free;
//  end;
//end;

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

end.

