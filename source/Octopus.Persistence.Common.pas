unit Octopus.Persistence.Common;

interface

uses
  Octopus.Process;

type
  IOctopusRepository = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function PublishDefinition(const Name: string; Process: TWorkflowProcess): string;
  end;

  IOctopusRuntime = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

end.
