unit Octopus.Persistence.Common;

interface

uses
  Octopus.Process;

type
  IProcessDefinition = interface
  ['{C0A9A5BA-4AEE-4ACE-B838-7BE217ABD3F8}']
    function GetId: string;
    function GetKey: string;
    function GetName: string;
    function GetProcess: string;
    function GetVersion: Integer;
    function GetCreatedOn: TDateTime;

    property Id: string read GetId;
    property Key: string read GetKey;
    property Name: string read GetName;
    property Process: string read GetProcess;
    property Version: Integer read GetVersion;
    property CreatedOn: TDateTime read GetCreatedOn;
  end;

  IOctopusRepository = interface
  ['{646F899B-9F4C-4452-9E29-8C0CC0EF3621}']
    function PublishDefinition(const Key, Process: string; const Name: string = ''): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
    function FindDefinitionByKey(const Key: string): IProcessDefinition;
  end;

  IOctopusRuntime = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function CreateInstance(const ProcessId: string): string;
    function GetInstanceProcessId(const InstanceId: string): string;
  end;

  IOctopusProcessFactory = interface
  ['{A668CF5F-A5FE-499F-A54C-4995E9FCCDC1}']
    procedure GetProcessDefinition(const ProcessId: string; var Process: TWorkflowProcess);
  end;

implementation

end.
