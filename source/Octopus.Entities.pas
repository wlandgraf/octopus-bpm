unit Octopus.Entities;

interface

uses
  Generics.Collections,
  Aurelius.Mapping.Attributes,
  Aurelius.Types.Blob,
  Aurelius.Types.Nullable,
  Aurelius.Types.Proxy;

const
  OctopusModel = 'Octopus';

type
  TOctopusProcessDefinition = class;
  TOctopusProcessInstance = class;
  TOctopusInstanceToken = class;
  TOctopusInstanceVariable = class;

  [Enumeration(TEnumMappingType.emString)]
  TProcessDefinitionStatus = (Draft, Published, Suspended);

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Id('FId', TIdGenerator.SmartGuid)]
  TOctopusProcessDefinition = class
  private
    FId: string;
    [Column('NAME', [TColumnProp.Unique])]
    FName: string;
    [Column('PROCESS', [TColumnProp.Lazy])]
    FProcess: TBlob;
    FVersion: integer;
    FStatus: TProcessDefinitionStatus;
  public
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Process: TBlob read FProcess write FProcess;
    property Version: integer read FVersion write FVersion;
    property Status: TProcessDefinitionStatus read FStatus write FStatus;
  end;

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Id('FId', TIdGenerator.SmartGuid)]
  TOctopusProcessVersion = class
  private
    FId: string;
    FDeployedOn: TDateTime;
    FDefinition: TOctopusProcessDefinition;
    [Column('PROCESS', [TColumnProp.Lazy])]
    FProcess: TBlob;
    FVersion: integer;
  public
    property Id: string read FId write FId;
    property DeployedOn: TDateTime read FDeployedOn write FDeployedOn;
    property Definition: TOctopusProcessDefinition read FDefinition write FDefinition;
    property Process: TBlob read FProcess write FProcess;
    property Version: integer read FVersion write FVersion;
  end;

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Id('FId', TIdGenerator.SmartGuid)]
  TOctopusProcessInstance = class
  private
    FId: string;
    FProcessVersion: TOctopusProcessVersion;
    FCreatedOn: TDateTime;
    FFinishedOn: Nullable<TDateTime>;
  public
    property Id: string read FId write FId;
    property ProcessVersion: TOctopusProcessVersion read FProcessVersion write FProcessVersion;
    property CreatedOn: TDateTime read FCreatedOn write FCreatedOn;
    property FinishedOn: Nullable<TDateTime> read FFinishedOn write FFinishedOn;
  end;

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Id('FId', TIdGenerator.SmartGuid)]
  TOctopusInstanceToken = class
  private
    FId: string;
    FInstance: TOctopusProcessInstance;
    FTransitionId: Nullable<string>;
    FNodeId: string;
    FNodeClass: string;
    FCreatedOn: TDateTime;
    FFinishedOn: Nullable<TDateTime>;
  public
    property Id: string read FId write FId;
    property CreatedOn: TDateTime read FCreatedOn write FCreatedOn;
    property FinishedOn: Nullable<TDateTime> read FFinishedOn write FFinishedOn;
    property TransitionId: Nullable<string> read FTransitionId write FTransitionId;
    property NodeId: string read FNodeId write FNodeId;
    property NodeClass: string read FNodeClass write FNodeClass;
    property Instance: TOctopusProcessInstance read FInstance write FInstance;
  end;

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Id('FId', TIdGenerator.SmartGuid)]
  TOctopusInstanceVariable = class
  private
    FId: string;
    FInstance: TOctopusProcessInstance;
    FToken: TOctopusInstanceToken;
    FName: string;
    FValue: TBlob;
    FValueType: string;
  public
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Value: TBlob read FValue write FValue;
    property ValueType: string read FValueType write FValueType;
    property Instance: TOctopusProcessInstance read FInstance write FInstance;
    property Token: TOctopusInstanceToken read FToken write FToken;
  end;

implementation

initialization
  RegisterEntity(TOctopusProcessDefinition);
  RegisterEntity(TOctopusProcessVersion);
  RegisterEntity(TOctopusProcessInstance);
  RegisterEntity(TOctopusInstanceToken);
  RegisterEntity(TOctopusInstanceVariable);

end.
