unit Octopus.Persistence.Common;

interface

uses
  System.Rtti,
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

  IProcessInstance = interface
  ['{605B80B3-F7D5-4D00-A1D4-444ECEB2D8E8}']
    function GetId: string;
    function GetProcessId: string;
    function GetReference: string;
    function GetCreatedOn: TDateTime;
    function GetFinishedOn: TDateTime;

    property Id: string read GetId;
    property ProcessId: string read GetProcessId;
    property Reference: string read GetReference;
    property CreatedOn: TDateTime read GetCreatedOn;
    property FinishedOn: TDateTime read GetFinishedOn;
  end;

  IInstanceQuery = interface
  ['{C306ADC2-09FE-425E-AC8B-9C2B352C6FA5}']
    function InstanceId(const AInstanceId: string): IInstanceQuery;
    function Reference(const AReference: string): IInstanceQuery;
    function VariableValueEquals(const AName: string; const AValue: TValue): IInstanceQuery;
    function Results: TArray<IProcessInstance>;
  end;

  IOctopusRepository = interface
  ['{646F899B-9F4C-4452-9E29-8C0CC0EF3621}']
    function PublishDefinition(const Key, Process: string; const Name: string = ''): string;
    function GetDefinition(const ProcessId: string): TWorkflowProcess;
    function FindDefinitionByKey(const Key: string): IProcessDefinition;
  end;

  IOctopusRuntime = interface
  ['{B56548F7-8E2B-441E-AE2A-9C04EED98B7D}']
    function CreateInstance(const ProcessId, Reference: string): string;
    function GetInstanceProcessId(const InstanceId: string): string;
    function CreateInstanceQuery: IInstanceQuery;
    function GetPendingInstances: TArray<IProcessInstance>;
  end;

  IOctopusInstanceService = interface
  ['{5155BBBF-BB17-46BC-823A-2193D5209259}']
    function LoadVariables: TArray<IVariable>;
    function LoadVariable(const Name: string; const TokenId: string = ''): IVariable;
    procedure SaveVariable(const Name: string; const Value: TValue; const TokenId: string = '');
  end;

  IOctopusProcessFactory = interface
  ['{A668CF5F-A5FE-499F-A54C-4995E9FCCDC1}']
    procedure GetProcessDefinition(const ProcessId: string; var Process: TWorkflowProcess);
  end;

implementation

end.
