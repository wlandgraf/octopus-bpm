unit Octopus.Persistence.Common;

interface

uses
  Octopus.Process;

type
  IOctopusRepository = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function PublishDefinition(const Name, JsonDefinition: string): string;
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

end.
