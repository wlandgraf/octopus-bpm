program TestPersistence;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {Form1},
  Octopus.Entities in '..\..\source\Octopus.Entities.pas',
  Octopus.Repository in '..\..\source\Octopus.Repository.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
