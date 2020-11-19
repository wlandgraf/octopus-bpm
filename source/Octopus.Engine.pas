unit Octopus.Engine;

interface

uses
  Octopus.Process;

type
  IOctopusEngine = interface
  ['{0AD90206-ABFD-4620-8A79-D7C3B17F7D20}']
    function PublishDefinition(const Name: string; const Process: string = ''): string;
    function CreateInstance(const ProcessId: string): string;
    procedure RunInstance(const InstanceId: string);
  end;

implementation

end.

