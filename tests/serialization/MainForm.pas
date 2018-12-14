unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, System.TypInfo, System.Rtti,
  Generics.Collections,
  Octopus.Process,
  Octopus.Process.Activities;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    mmProcess: TMemo;
    btSerializeProcess: TButton;
    btDeserializeProcess: TButton;
    btSerializeInstance: TButton;
    btDeserializeInstance: TButton;
    mmInstance: TMemo;
    procedure btSerializeProcessClick(Sender: TObject);
    procedure btDeserializeProcessClick(Sender: TObject);
    procedure btSerializeInstanceClick(Sender: TObject);
    procedure btDeserializeInstanceClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    function SampleObject: TObject;
    function SampleProcess(AObj: TObject): TWorkflowProcess;
    function SampleActivity: TActivity;
  public
    procedure InitiateAction; override;
  end;

  TInfo = class
    [Persistent]
    Description: string;
    [Persistent]
    CreatedOn: TDateTime;
  end;

  TTestActivity = class(TActivity)
    [Persistent]
    SecretCode: string;
    [Persistent]
    Answer: integer;
    [Persistent]
    Closed: boolean;
  public
    procedure ExecuteInstance(Context: TActivityExecutionContext); override;
  end;

var
  Form1: TForm1;

implementation

uses
  Octopus.Process.Builder,
  Octopus.Engine.Runner,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer,
  Octopus.DataTypes;

{$R *.dfm}

procedure TForm1.btDeserializeInstanceClick(Sender: TObject);
//var
//  instance: TProcessInstance;
//  T: TToken;
//  D: TPair<string,TValue>;
//  process: TWorkflowProcess;
begin
//  process := TWorkflowDeserializer.ProcessFromJson(mmProcess.Lines.Text);
//  instance := TWorkflowDeserializer.InstanceFromJson(mmInstance.Lines.Text, process);
//  try
//    mmInstance.Lines.Clear;
//
//    mmInstance.Lines.Add('Status: ' + GetEnumName(TypeInfo(TInstanceStatus), Ord(instance.Status)));
//    mmInstance.Lines.Add('Tokens:');
//    for T in instance.Tokens do
//      if T.Transition <> nil then
//        mmInstance.Lines.Add(Format('  %s (%s) --> %s (%s)', [T.Transition.Source.ClassName, T.Transition.Source.Id, T.Transition.Target.ClassName, T.Transition.Target.Id]))
//      else
//        mmInstance.Lines.Add('  Unassigned token transition');
//    mmInstance.Lines.Add('Data:');
//    for D in instance.Data do
//      mmInstance.Lines.Add(Format('  %s = %s', [D.Key, D.Value.ToString]));
//  finally
//    instance.Free;
//    process.Free;
//  end;
end;

procedure TForm1.btDeserializeProcessClick(Sender: TObject);
var
  process: TWorkflowProcess;
  N: TFlowNode;
  T: TTransition;
  V: TVariable;
begin
  process := TWorkflowDeserializer.ProcessFromJson(mmProcess.Lines.Text);
  try
    mmProcess.Lines.Clear;

    mmProcess.Lines.Add(Format('[Nodes (%d)]', [Process.Nodes.Count]));
    for N in Process.Nodes do
      mmProcess.Lines.Add(Format('%s (%s)', [N.ClassName, N.Id]));
    mmProcess.Lines.Add('');

    mmProcess.Lines.Add(Format('[Transitions (%d)]', [Process.Transitions.Count]));
    for T in Process.Transitions do
      mmProcess.Lines.Add(Format('%s (%s) --> %s (%s)', [T.Source.ClassName, T.Source.Id, T.Target.ClassName, T.Target.Id]));
    mmProcess.Lines.Add('');

    mmProcess.Lines.Add(Format('[Variables (%d)]', [Process.Variables.Count]));
    for V in Process.Variables do
      mmProcess.Lines.Add(Format('%s = %s', [V.Name, V.DefaultValue.ToString]));
    mmProcess.Lines.Add('');
  finally
    process.Free;
  end;
end;

procedure TForm1.btSerializeInstanceClick(Sender: TObject);
//var
//  process: TWorkflowProcess;
//  instance: TProcessInstance;
//  runner: TWorkflowRunner;
begin
//  process := TWorkflowDeserializer.ProcessFromJson(mmProcess.Lines.Text);
//  instance := TProcessInstance.Create;
//  runner := TWorkflowRunner.Create(instance, process);
//  try
//    runner.Execute;
//    mmInstance.Lines.Text := TWorkflowSerializer.InstanceToJson(instance, process);
//  finally
//    instance.Free;
//    process.Free;
//    runner.Free;
//  end;
end;

procedure TForm1.btSerializeProcessClick(Sender: TObject);
var
  process: TWorkflowProcess;
begin
  process := SampleProcess(SampleObject);
  try
    mmProcess.Lines.Text := TWorkflowSerializer.ProcessToJson(process);
  finally
    process.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  OT: TOctopusDataType;
begin
  OT := TOctopusDataType.Create;
  OT.Name := 'TInfo';
  OT.NativeType := TypeInfo(TInfo);
  TOctopusDataTypes.Default.RegisterType(OT);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  mmInstance.Width := ClientWidth div 2;
end;

procedure TForm1.InitiateAction;
var
  objProcess, objInstance: boolean;
begin
  inherited;
  objProcess := (mmProcess.Lines.Text > '') and (mmProcess.Lines.Text[1] = '{');
  objInstance := (mmInstance.Lines.Text > '') and (mmInstance.Lines.Text[1] = '{');
  btDeserializeProcess.Enabled := objProcess;
  btSerializeInstance.Enabled := objProcess;
  btDeserializeInstance.Enabled := objProcess and objInstance;
end;

function TForm1.SampleActivity: TActivity;
var
  test: TTestActivity;
begin
  test := TTestActivity.Create;
  test.SecretCode := '1283081278973867823648762846283648';
  test.Answer := 42;
  result := test;
end;

function TForm1.SampleObject: TObject;
var
  info: TInfo;
begin
  info := TInfo.Create;
  info.Description := 'Test';
  info.CreatedOn := Now;
  result := info;
end;

function TForm1.SampleProcess(AObj: TObject): TWorkflowProcess;
var
  builder: TProcessBuilder;
begin
  result := TWorkflowProcess.Create;
  builder := TProcessBuilder.Create(result);
  try
    builder
      .Variable('Title', 'Workflow demo')
      .Variable('Year', 2016)
      .Variable('Obj', AObj)
      .Variable('Pi', 3.14159)
      .Variable('Empty')
      .StartEvent
      .Activity(SampleActivity).Id('MyTestActivity')
      .ExclusiveGateway.Id('decision')
      .EndEvent
      .GotoLastGateway
      .LinkTo('MyTestActivity');
  finally
    builder.Free
  end;
end;

{ TTestActivity }

procedure TTestActivity.ExecuteInstance(Context: TActivityExecutionContext);
begin
  Context.Done := false;
end;

end.

