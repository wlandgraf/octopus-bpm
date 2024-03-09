unit Octopus.Job.Runner;

interface

uses
  System.Generics.Collections, System.SysUtils, System.DateUtils, System.Math,
  Sparkle.Sys.JobRunner,
  Octopus.Engine;

type
  TOctopusJobRunner = class(TCustomJobRunner)
  strict private
    FEngine: IOctopusEngine;
    FInstanceBatchSize: Integer;
    FInstancesPerJob: Integer;
  protected
    procedure ProcessJob; override;
  public
    constructor Create(AEngine: IOctopusEngine); reintroduce;
    property InstanceBatchSize: Integer read FInstanceBatchSize write FInstanceBatchSize;
    property InstancesPerJob: Integer read FInstancesPerJob write FInstancesPerJob;
  end;

implementation

{ TOctopusJobRunner }

constructor TOctopusJobRunner.Create(AEngine: IOctopusEngine);
begin
  inherited Create;
  FEngine := AEngine;
  FInstanceBatchSize := 5;
  FInstancesPerJob := 1000;
end;

procedure TOctopusJobRunner.ProcessJob;
var
  Processed: Integer;
  Remaining: Integer;
begin
  Remaining := InstancesPerJob;
  repeat
    Processed := FEngine.RunPendingInstances(Min(InstanceBatchSize, Remaining));
    Remaining := Remaining - Processed;
  until (Processed = 0) or (Remaining <= 0) or StopRequested;
end;

end.
