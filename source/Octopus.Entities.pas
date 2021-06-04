unit Octopus.Entities;

{$I Octopus.inc}

// Allow method-based validations
{$RTTI EXPLICIT METHODS([vcPrivate..vcPublished])}

interface

uses
  Generics.Collections, Variants,
  Aurelius.Id.Guid,
  Aurelius.Mapping.Attributes,
  Aurelius.Types.Blob,
  Aurelius.Types.Nullable,
  Aurelius.Types.Proxy,
  Aurelius.Validation;

const
  OctopusModel = 'Octopus';

type
  TProcessDefinitionEntity = class;
  TProcessInstanceEntity = class;
  TTokenEntity = class;
  TVariableEntity = class;

  [Enumeration(TEnumMappingType.emInteger)]
  TProcessDefinitionStatus = (Published, Suspended);

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Table('OCT_PROC_DEFINITION')]
  [Sequence('SEQ_PROC_DEFINITION')]
  [UniqueKey('KEY,VERSION')]
  [Id('FId', TSmartGuid32LowerGenerator)]
  TProcessDefinitionEntity = class
  strict private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate], 40)]
    FId: string;
    [Version]
    FRowVersion: Integer;
    [Column('KEY', [TColumnProp.Required, TColumnProp.NoUpdate], 255)]
    FKey: string;
    [Column('NAME', [], 255)]
    FName: string;
    FVersion: Integer;
    FStatus: TProcessDefinitionStatus;
    FCreatedOn: TDateTime;
    [Column('PROCESS', [TColumnProp.Lazy])]
    FProcess: TBlob;
  strict protected
    property RowVersion: Integer read FRowVersion;
  public
    property Id: string read FId write FId;
    property Key: string read FKey write FKey;
    property Name: string read FName write FName;
    property Process: TBlob read FProcess write FProcess;
    property Version: integer read FVersion write FVersion;
    property Status: TProcessDefinitionStatus read FStatus write FStatus;
    property CreatedOn: TDateTime read FCreatedOn write FCreatedOn;
  end;

  [Enumeration(TEnumMappingType.emInteger)]
  TProcessInstanceStatus = (Active, Finished);

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Table('OCT_PROC_INSTANCE')]
  [Sequence('SEQ_PROC_INSTANCE')]
  [DBIndex('idx_oct_proc_instance_status', 'status')]
  [Id('FId', TSmartGuid32LowerGenerator)]
  TProcessInstanceEntity = class
  private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate], 40)]
    FId: string;
    [Version]
    FRowVersion: Integer;
    [Association([TAssociationProp.Lazy], [TCascadeType.SaveUpdate])]
    [JoinColumn('PROC_DEFINITION_ID', [])]
    FProcessDefinition: Proxy<TProcessDefinitionEntity>;
    [Column('CREATED_ON', [TColumnProp.Required, TColumnProp.NoUpdate])]
    FCreatedOn: TDateTime;
    FFinishedOn: Nullable<TDateTime>;
    FReference: Nullable<string>;
    FStatus: TProcessInstanceStatus;
    FLockExpiration: Nullable<TDateTime>;
    FDueDate: Nullable<TDateTime>;
    function GetProcessDefinition: TProcessDefinitionEntity;
    procedure SetProcessDefinition(const Value: TProcessDefinitionEntity);
    function GetProcessId: string;
  strict protected
    property RowVersion: Integer read FRowVersion;
  public
    property Id: string read FId write FId;
    property ProcessDefinition: TProcessDefinitionEntity read GetProcessDefinition write SetProcessDefinition;
    property Reference: Nullable<string> read FReference write FReference;
    property CreatedOn: TDateTime read FCreatedOn write FCreatedOn;
    property FinishedOn: Nullable<TDateTime> read FFinishedOn write FFinishedOn;
    property Status: TProcessInstanceStatus read FStatus write FStatus;
    property ProcessId: string read GetProcessId;
    property LockExpiration: Nullable<TDateTime> read FLockExpiration write FLockExpiration;
    property DueDate: Nullable<TDateTime> read FDueDate write FDueDate;
  end;

  [Enumeration(TEnumMappingType.emInteger)]
  TTokenEntityStatus = (Active, Waiting, Finished);

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Table('OCT_TOKEN')]
  [Sequence('SEQ_TOKEN')]
  [DBIndex('idx_oct_token_proc_instance_id', 'proc_instance_id')]
  [Id('FId', TSmartGuid32LowerGenerator)]
  TTokenEntity = class
  private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate], 40)]
    FId: string;
    [Version]
    FRowVersion: Integer;
    [Association([TAssociationProp.Required, TAssociationProp.Lazy], [TCascadeType.SaveUpdate])]
    [JoinColumn('PROC_INSTANCE_ID', [TColumnProp.Required])]
    FInstance: Proxy<TProcessInstanceEntity>;
    [Association([TAssociationProp.Lazy], [TCascadeType.SaveUpdate])]
    [JoinColumn('PARENT_ID', [])]
    FParent: Proxy<TTokenEntity>;
    FCreatedOn: TDateTime;
    FFinishedOn: Nullable<TDateTime>;
    FStatus: TTokenEntityStatus;
    FTransitionId: Nullable<string>;
    FNodeId: Nullable<string>;
    FProducerId: Nullable<string>;
    FConsumerId: Nullable<string>;
    function GetInstance: TProcessInstanceEntity;
    procedure SetInstance(const Value: TProcessInstanceEntity);
    function GetParent: TTokenEntity;
    procedure SetParent(const Value: TTokenEntity);
    function GetParentId: string;
  strict protected
    [OnValidate]
    function OnValidateParent(Context: IValidationContext): IValidationResult;
  strict protected
    property RowVersion: Integer read FRowVersion;
  public
    property Id: string read FId write FId;
    property CreatedOn: TDateTime read FCreatedOn write FCreatedOn;
    property FinishedOn: Nullable<TDateTime> read FFinishedOn write FFinishedOn;
    property TransitionId: Nullable<string> read FTransitionId write FTransitionId;
    property Parent: TTokenEntity read GetParent write SetParent;
    property ParentId: string read GetParentId;
    property NodeId: Nullable<string> read FNodeId write FNodeId;
    property ConsumerId: Nullable<string> read FConsumerId write FConsumerId;
    property ProducerId: Nullable<string> read FProducerId write FProducerId;
    property Instance: TProcessInstanceEntity read GetInstance write SetInstance;
    property Status: TTokenEntityStatus read FStatus write FStatus;

  end;

  [Entity, Automapping]
  [Model(OctopusModel)]
  [Table('OCT_VARIABLE')]
  [Sequence('SEQ_VARIABLE')]
//  [DBIndex('idx_oct_variable_name', 'name')]
  [DBIndex('idx_oct_variable_instance_id', 'proc_instance_id')]
  [Id('FId', TSmartGuid32LowerGenerator)]
  TVariableEntity = class
  private
    [Column('ID', [TColumnProp.Required, TColumnProp.NoUpdate], 40)]
    FId: string;
    [Version]
    FRowVersion: Integer;
    FName: string;

    [DBTypeWideMemo]
    [Column('_VALUE', [], 65536)]
    FValue: string;

    [Column('INT64_VALUE')]
    FInt64Value: Nullable<Int64>;

    [Column('STRING_VALUE')]
    FStringValue: Nullable<string>;

    [Column('DOUBLE_VALUE')]
    FDoubleValue: Nullable<Double>;

    [Column('VALUE_TYPE', [], 255)]
    FValueType: string;

    [Association([TAssociationProp.Required, TAssociationProp.Lazy], [TCascadeType.SaveUpdate])]
    [JoinColumn('PROC_INSTANCE_ID', [TColumnProp.Required])]
    FInstance: Proxy<TProcessInstanceEntity>;

    [Association([TAssociationProp.Lazy], [TCascadeType.SaveUpdate])]
    [JoinColumn('TOKEN_ID', [])]
    FToken: Proxy<TTokenEntity>;
    function GetInstance: TProcessInstanceEntity;
    function GetToken: TTokenEntity;
    procedure SetInstance(const Value: TProcessInstanceEntity);
    procedure SetToken(const Value: TTokenEntity);
    function GetTokenId: string;
  strict protected
    property RowVersion: Integer read FRowVersion;
  public
    procedure ClearValue;
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
    property Int64Value: Nullable<Int64> read FInt64Value write FInt64Value;
    property StringValue: Nullable<string> read FStringValue write FStringValue;
    property DoubleValue: Nullable<Double> read FDoubleValue write FDoubleValue;
    property ValueType: string read FValueType write FValueType;
    property Instance: TProcessInstanceEntity read GetInstance write SetInstance;
    property Token: TTokenEntity read GetToken write SetToken;
    property TokenId: string read GetTokenId;
  end;

implementation

uses
  Octopus.Resources;

{ TProcessInstanceEntity }

function TProcessInstanceEntity.GetProcessDefinition: TProcessDefinitionEntity;
begin
  Result := FProcessDefinition.Value;
end;

function TProcessInstanceEntity.GetProcessId: string;
begin
  if FProcessDefinition.Available then
  begin
    if Assigned(FProcessDefinition.Value) then
      Result := FProcessDefinition.Value.Id
    else
      Result := '';
  end
  else
    Result := VarToStr(FProcessDefinition.Key);
end;

procedure TProcessInstanceEntity.SetProcessDefinition(
  const Value: TProcessDefinitionEntity);
begin
  FProcessDefinition.Value := Value;
end;

{ TTokenEntity }

function TTokenEntity.GetInstance: TProcessInstanceEntity;
begin
  Result := FInstance.Value;
end;

function TTokenEntity.GetParent: TTokenEntity;
begin
  Result := FParent.Value;
end;

function TTokenEntity.GetParentId: string;
begin
  if FParent.Available then
  begin
    if Assigned(FParent.Value) then
      Result := FParent.Value.Id
    else
      Result := '';
  end
  else
    Result := VarToStr(FParent.Key);
end;

function TTokenEntity.OnValidateParent(
  Context: IValidationContext): IValidationResult;
begin
  if (TransitionId.ValueOrDefault <> '') and FParent.Available and not Assigned(FParent.Value) then
    Result := TValidationResult.Failed(STokenValidationParentRequired)
  else
    Result := TValidationResult.Success;
end;

procedure TTokenEntity.SetInstance(const Value: TProcessInstanceEntity);
begin
  FInstance.Value := Value;
end;

procedure TTokenEntity.SetParent(const Value: TTokenEntity);
begin
  FParent.Value := Value;
end;

{ TVariableEntity }

procedure TVariableEntity.ClearValue;
begin
  Value := '';
  Int64Value := SNull;
  StringValue := SNull;
  DoubleValue := SNull;
end;

function TVariableEntity.GetInstance: TProcessInstanceEntity;
begin
  Result := FInstance.Value;
end;

function TVariableEntity.GetToken: TTokenEntity;
begin
  Result := FToken.Value;
end;

function TVariableEntity.GetTokenId: string;
begin
  if FToken.Available then
  begin
    if Assigned(FToken.Value) then
      Result := FToken.Value.Id
    else
      Result := '';
  end
  else
    Result := VarToStr(FToken.Key);
end;

procedure TVariableEntity.SetInstance(const Value: TProcessInstanceEntity);
begin
  FInstance.Value := Value;
end;

procedure TVariableEntity.SetToken(const Value: TTokenEntity);
begin
  FToken.Value := Value;
end;

initialization
  RegisterEntity(TProcessDefinitionEntity);
  RegisterEntity(TProcessInstanceEntity);
  RegisterEntity(TTokenEntity);
  RegisterEntity(TVariableEntity);

end.
