unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Attributes,
  Aurelius.Mapping.Explorer,
  Aurelius.Types.Blob,
  Aurelius.Types.Nullable,
  Octopus.Process,
  Octopus.Process.Builder,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer,
  Octopus.Repository;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    FConnection: IDBConnection;
    FRepository: IOctopusRepository;
  public
  end;

var
  Form1: TForm1;

implementation

uses
  Aurelius.Drivers.SQLite,
  Aurelius.Engine.DatabaseManager,
  Aurelius.Sql.SQLite,
  Aurelius.Schema.SQLite,
  Octopus.Entities;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
  dbmanager: TDatabaseManager;
  sql: string;
begin
  dbmanager := TDatabaseManager.Create(FConnection, TMappingExplorer.Get(OctopusModel));
  try
    dbmanager.DestroyDatabase;
    dbmanager.UpdateDatabase;

    Memo1.Lines.Clear;
    for sql in dbmanager.SQLStatements do
      Memo1.Lines.Add(sql);
  finally
    dbmanager.Free;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  process: TWorkflowProcess;
  builder: TProcessBuilder;
begin
  process := TWorkflowProcess.Create;
  builder := TProcessBuilder.Create(process);
  builder.StartEvent.EndEvent;

  Memo1.Lines.Text := FRepository.CreateProcessDefinition(Format('NewProcess%d', [Random(1000)]));

  process.Free;
  builder.Free;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  defs: TList<TOctopusProcessDefinition>;
  def: TOctopusProcessDefinition;
begin
  defs := FRepository.ListProcessDefinitions;
  try
    Memo1.Lines.Clear;
    for def in defs do
    begin
      Memo1.Lines.Add(def.Id);
      Memo1.Lines.Add(def.Name);
      Memo1.Lines.Add('');
    end;
  finally
    defs.Free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  key: string;
  process: TWorkflowProcess;
begin
  key := InputBox('process def key', 'key:', '');
  process := FRepository.GetProcessDefinition(key);
  if process <> nil then
  begin
    Memo1.Lines.Text := TWorkflowSerializer.ProcessToJson(process);
    process.Free;
  end
  else
    Memo1.Lines.Text := '(not found)';
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  key: string;
  process: TWorkflowProcess;
  builder: TProcessBuilder;
begin
  key := InputBox('process def key', 'key:', '');;

  process := TWorkflowProcess.Create;
  builder := TProcessBuilder.Create(process);
  builder.StartEvent.EndEvent;

  FRepository.UpdateProcessDefinition(key, process);
  Memo1.Lines.Text := 'OK';

  process.Free;
  builder.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FConnection := TSQLiteNativeConnectionAdapter.Create('octopus.db');
  FRepository := TOctopusRepository.Create(FConnection);
end;

end.

