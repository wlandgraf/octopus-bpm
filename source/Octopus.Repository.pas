unit Octopus.Repository;

interface

uses
  Generics.Collections,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Explorer,
  Octopus.Entities,
  Octopus.Process;

type
  IOctopusRepository = interface
    function CreateProcessDefinition(Name: string): string;
    function ListProcessDefinitions: TList<TOctopusProcessDefinition>;
    function GetProcessDefinition(Id: string): TWorkflowProcess;
    procedure UpdateProcessDefinition(Id: string; Process: TWorkflowProcess);
  end;

  TOctopusRepository = class(TInterfacedObject, IOctopusRepository)
  private
    FManager: TObjectManager;
  public
    constructor Create(Connection: IDBConnection);
    destructor Destroy; override;
    function CreateProcessDefinition(Name: string): string;
    function ListProcessDefinitions: TList<TOctopusProcessDefinition>;
    function GetProcessDefinition(Id: string): TWorkflowProcess;
    procedure UpdateProcessDefinition(Id: string; Process: TWorkflowProcess);
  end;

implementation

uses
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer;

{ TOctopusRepository }

constructor TOctopusRepository.Create(Connection: IDBConnection);
begin
  FManager := TObjectManager.Create(Connection, TMappingExplorer.Get(OctopusModel));
end;

function TOctopusRepository.CreateProcessDefinition(Name: string): string;
var
  def: TOctopusProcessDefinition;
begin
  def := TOctopusProcessDefinition.Create;
  def.Name := Name;
  FManager.Save(def);
end;

destructor TOctopusRepository.Destroy;
begin
  FManager.Free;
  inherited;
end;

function TOctopusRepository.GetProcessDefinition(Id: string): TWorkflowProcess;
var
  def: TOctopusProcessDefinition;
begin
  def := FManager.Find<TOctopusProcessDefinition>(Id);
  if (def <> nil) and not def.Process.IsNull then
    result := TWorkflowDeserializer.ProcessFromJson(def.Process.AsString)
  else
    result := nil;
end;

function TOctopusRepository.ListProcessDefinitions: TList<TOctopusProcessDefinition>;
begin
  result := FManager.Find<TOctopusProcessDefinition>.List;
end;

procedure TOctopusRepository.UpdateProcessDefinition(Id: string; Process: TWorkflowProcess);
var
  def: TOctopusProcessDefinition;
begin
  def := FManager.Find<TOctopusProcessDefinition>(Id);
  if def <> nil then
  begin
    def.Process.AsString := TWorkflowSerializer.ProcessToJson(Process);
    FManager.Flush;
  end;
end;

end.
