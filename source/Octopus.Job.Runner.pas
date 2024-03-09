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
  Total: Integer;
begin
  Total := 0;
  repeat
    Processed := FEngine.RunPendingInstances(InstanceBatchSize);
    Total := Total + Processed;
  until (Processed = 0) or (Total >= InstancesPerJob) or StopRequested;
end;

end.
