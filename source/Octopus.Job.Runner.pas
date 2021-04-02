unit Octopus.Job.Runner;

interface

uses
  System.Generics.Collections, System.SysUtils, System.DateUtils,
  Sparkle.Sys.JobRunner,
  Octopus.Engine;

type
  TOctopusJobRunner = class(TCustomJobRunner)
  strict private
    FEngine: IOctopusEngine;
  protected
    procedure ProcessJob; override;
  public
    constructor Create(AEngine: IOctopusEngine); reintroduce;
  end;

implementation

{ TOctopusJobRunner }

constructor TOctopusJobRunner.Create(AEngine: IOctopusEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TOctopusJobRunner.ProcessJob;
begin
  FEngine.RunPendingInstances;
end;

end.
