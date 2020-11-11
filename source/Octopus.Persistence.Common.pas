unit Octopus.Persistence.Common;

interface

uses
  Octopus.Process;

type
  IInstancePersistence = interface
  ['{3A1819A3-2889-4F99-947D-8DB78172B9A6}']
    function CreateInstance(const ProcessId: string): IProcessInstanceData;
  end;

implementation

end.
