unit Octopus.Persistence.Common;

interface

uses
  Octopus.Process;

type
  IOctopusRepository = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function PublishDefinition(const Name: string; Process: TWorkflowProcess): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
  end;

  IOctopusRuntime = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function CreateInstance(const ProcessId: string): string;
    function GetInstanceProcessId(const InstanceId: string): string;
  end;

  IOctopusProcessFactory = interface
  ['{A668CF5F-A5FE-499F-A54C-4995E9FCCDC1}']
    procedure GetProcessDefinition(const ProcessName: string; Version: Integer;
      var Process: TWorkflowProcess);
  end;

implementation

end.
