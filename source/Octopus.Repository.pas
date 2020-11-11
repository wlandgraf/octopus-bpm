unit Octopus.Repository;

interface

uses
  Generics.Collections,
  System.SysUtils,
  Aurelius.Drivers.Interfaces,
  Aurelius.Engine.ObjectManager,
  Aurelius.Mapping.Explorer,
  Octopus.Entities,
  Octopus.Process;

//type
//  IOctopusRepository = interface
//  ['{7CC984E2-4BB4-4C23-886A-19C2DEE8C493}']
//    function CreateProcessDefinition(const Name: string): string;
//    function ListProcessDefinitions: TList<TProcessDefinitionEntity>;
//    function GetProcessDefinition(const Id: string): TWorkflowProcess;
//    procedure UpdateProcessDefinition(const Id: string; Process: TWorkflowProcess);
//    function PublishDefinition(const Name, JsonDefinition: string): string;
//  end;

//  TOctopusRepository = class(TInterfacedObject, IOctopusRepository)
//  private
//    FPool: IDBConnectionPool;
//  protected
//    function CreateManager: TObjectManager;
//    property Pool: IDBConnectionPool read FPool;
//  public
//    constructor Create(Pool: IDBConnectionPool);
//    destructor Destroy; override;
//  public
//    function PublishDefinition(const Name, JsonDefinition: string): string;
//    function CreateProcessDefinition(const Name: string): string;
//    function ListProcessDefinitions: TList<TProcessDefinitionEntity>;
//    function GetProcessDefinition(const Id: string): TWorkflowProcess;
//    procedure UpdateProcessDefinition(const Id: string; Process: TWorkflowProcess);
//  end;

implementation

uses
  Aurelius.Criteria.Base,
  Aurelius.Criteria.Linq,
  Octopus.Json.Serializer,
  Octopus.Json.Deserializer;

{ TOctopusRepository }

//constructor TOctopusRepository.Create(Pool: IDBConnectionPool);
//begin
//  FPool := Pool;
//end;

//function TOctopusRepository.CreateProcessDefinition(const Name: string): string;
//var
//  def: TProcessDefinitionEntity;
//begin
//  def := TProcessDefinitionEntity.Create;
//  def.Name := Name;
//  FManager.Save(def);
//  Result := def.Id;
//end;

//destructor TOctopusRepository.Destroy;
//begin
//  FManager.Free;
//  inherited;
//end;

//function TOctopusRepository.GetProcessDefinition(const Id: string): TWorkflowProcess;
//var
//  def: TProcessDefinitionEntity;
//begin
//  def := FManager.Find<TProcessDefinitionEntity>(Id);
//  if (def <> nil) and not def.Process.IsNull then
//    result := TWorkflowDeserializer.ProcessFromJson(def.Process.AsString)
//  else
//    result := nil;
//end;

//function TOctopusRepository.ListProcessDefinitions: TList<TProcessDefinitionEntity>;
//begin
//  result := FManager.Find<TProcessDefinitionEntity>.List;
//end;

//procedure TOctopusRepository.UpdateProcessDefinition(const Id: string; Process: TWorkflowProcess);
//var
//  def: TProcessDefinitionEntity;
//begin
//  def := FManager.Find<TProcessDefinitionEntity>(Id);
//  if def <> nil then
//  begin
//    def.Process.AsString := TWorkflowSerializer.ProcessToJson(Process);
//    FManager.Flush;
//  end;
//end;

//function TOctopusRepository.CreateManager: TObjectManager;
//begin
//  Result := TObjectManager.Create(Pool.GetConnection, TMappingExplorer.Get(OctopusModel));
//end;

//function TOctopusRepository.PublishDefinition(const Name,
//  JsonDefinition: string): string;
//var
//  Manager: TObjectManager;
//  VersionResult: TCriteriaResult;
//  NextVersion: Integer;
//  Definition: TProcessDefinitionEntity;
//begin
//  Manager := CreateManager;
//  try
//    VersionResult := Manager.Find<TProcessDefinitionEntity>
//      .Select(Linq['Version'].Max)
//      .Where(Linq['Name'].ILike(Name))
//      .UniqueValue;
//    try
//      NextVersion := VersionResult.Values[0] + 1;
//    finally
//      VersionResult.Free;
//    end;
//
//    Definition := TProcessDefinitionEntity.Create;
//    Manager.AddToGarbage(Definition);
//    Definition.Name := Name;
//    Definition.Version := NextVersion;
//    Definition.Status := TProcessDefinitionStatus.Published;
//    Definition.CreatedOn := Now;
//    Definition.Process.AsUnicodeString := JsonDefinition;
//    Manager.Save(Definition);
//    Result := Definition.Id;
//  finally
//    Manager.Free;
//  end;
//end;

end.
