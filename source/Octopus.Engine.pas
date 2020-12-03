unit Octopus.Engine;

interface

uses
  Generics.Collections,
  Octopus.Process,
  Octopus.Persistence.Common;

type
  IOctopusEngine = interface
  ['{0AD90206-ABFD-4620-8A79-D7C3B17F7D20}']
    function PublishDefinition(const Key, Process: string; const Name: string = ''): string;
    function FindDefinitionByKey(const Key: string): IProcessDefinition;

    function CreateInstance(const ProcessId: string): string; overload;
    function CreateInstance(const ProcessId: string; Variables: TEnumerable<TVariable>): string; overload;
    procedure RunInstance(const InstanceId: string);
  end;

implementation

end.

