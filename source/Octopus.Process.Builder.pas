unit Octopus.Process.Builder;

interface

uses
  System.SysUtils,
  System.Rtti,
  Generics.Collections,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Process.Events,
  Octopus.Process.Gateways;

type
  TProcessBuilder = class
  private
    FProcess: TWorkflowProcess;
    FParent: TProcessBuilder;
    FItems: TObjectList<TProcessBuilder>;
    FElement: TFlowElement;
    function GetCurrentNode: TFlowNode;
    function GetCurrentTransition: TTransition;
  protected
    function BuildItem(AElement: TFlowElement; Linked: boolean): TProcessBuilder;
    property CurrentElement: TFlowElement read FElement;
    property CurrentNode: TFlowNode read GetCurrentNode;
    property CurrentTransition: TTransition read GetCurrentTransition;
  public
    constructor Create(AProcess: TWorkflowProcess);
    destructor Destroy; override;
    function AddNode(Node: TFlowNode): TFlowNode;
    function AddTransition(Source, Target: TFlowNode): TTransition;
    function AddStartEvent: TStartEvent;
    function AddEndEvent: TEndEvent;
    function AddVariable(AName: string; ADefaultValue: TValue): TVariable;

    // fluent interface methods
    function Activity(AClass: TActivityClass): TProcessBuilder; overload;
    function Activity(AActivity: TActivity): TProcessBuilder; overload;
    function Condition(AProc: TEvaluateProc): TProcessBuilder;
    function EndEvent: TProcessBuilder;
    function ExclusiveGateway: TProcessBuilder;
    function Get(out ANode: TFlowNode): TProcessBuilder;
    function GotoElement(AElement: TFlowElement): TProcessBuilder; overload;
    function GotoElement(AId: string): TProcessBuilder; overload;
    function GotoLastGateway: TProcessBuilder;
    function Id(AId: string): TProcessBuilder;
    function InclusiveGateway: TProcessBuilder;
    function LinkTo(ANode: TFlowNode): TProcessBuilder; overload;
    function LinkTo(ElementId: string): TProcessBuilder; overload;
    function ParallelGateway: TProcessBuilder;
    function StartEvent: TProcessBuilder;
    function Variable(AName: string): TProcessBuilder; overload;
    function Variable(AName: string; ADefaultValue: TValue): TProcessBuilder; overload;
  end;

implementation

uses
  Octopus.Resources;

{ TProcessBuilder }

function TProcessBuilder.Activity(AClass: TActivityClass): TProcessBuilder;
begin
  result := Activity(AClass.Create);
end;

function TProcessBuilder.Activity(AActivity: TActivity): TProcessBuilder;
begin
  result := BuildItem(AddNode(AActivity), true);
end;

function TProcessBuilder.AddNode(Node: TFlowNode): TFlowNode;
begin
  FProcess.Nodes.Add(Node);
  result := Node;
end;

function TProcessBuilder.AddEndEvent: TEndEvent;
begin
  result := TEndEvent.Create;
  FProcess.Nodes.Add(result);
end;

function TProcessBuilder.AddTransition(Source, Target: TFlowNode): TTransition;
begin
  result := TTransition.Create;
  result.Source := Source;
  result.Target := Target;
  FProcess.Transitions.Add(result);
end;

function TProcessBuilder.AddVariable(AName: string; ADefaultValue: TValue): TVariable;
begin
  result := TVariable.Create;
  result.Name := AName;
  result.DefaultValue := ADefaultValue;
  FProcess.Variables.Add(result);
end;

function TProcessBuilder.BuildItem(AElement: TFlowElement; Linked: boolean): TProcessBuilder;
begin
  result := TProcessBuilder.Create(FProcess);
  result.FParent := Self;
  result.FElement := AElement;

  if Linked then
  begin
    if CurrentElement is TFlowNode then // new transition
      AddTransition(Self.CurrentNode, result.CurrentNode)
    else if CurrentElement is TTransition then // target for the current transition
      CurrentTransition.Target := result.CurrentNode;
  end;

  FItems.Add(result);
end;

function TProcessBuilder.Condition(AProc: TEvaluateProc): TProcessBuilder;
var
  transition: TTransition;
begin
  transition := AddTransition(CurrentNode, nil);
  transition.SetCondition(AProc);
  result := BuildItem(transition, false);
end;

constructor TProcessBuilder.Create(AProcess: TWorkflowProcess);
begin
  FProcess := AProcess;
  FItems := TObjectList<TProcessBuilder>.Create;
end;

destructor TProcessBuilder.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TProcessBuilder.EndEvent: TProcessBuilder;
begin
  result := BuildItem(AddEndEvent, true);
end;

function TProcessBuilder.ExclusiveGateway: TProcessBuilder;
begin
  result := BuildItem(AddNode(TExclusiveGateway.Create), true);
end;

function TProcessBuilder.Get(out ANode: TFlowNode): TProcessBuilder;
begin
  ANode := CurrentNode;
  result := Self;
end;

function TProcessBuilder.GetCurrentNode: TFlowNode;
begin
  if Assigned(FElement) and (FElement is TFlowNode) then
    result := TActivity(FElement)
  else
    raise Exception.Create(SBuilderCurrentNodeError);
end;

function TProcessBuilder.GetCurrentTransition: TTransition;
begin
  if Assigned(FElement) and (FElement is TTransition) then
    result := TTransition(FElement)
  else
    raise Exception.Create(SBuilderCurrentTransitionError);
end;

function TProcessBuilder.GotoElement(AId: string): TProcessBuilder;
begin
  if Assigned(FElement) then
    if SameText(FElement.Id, AId) then
      exit(Self)
    else if Assigned(FParent) then
      exit(FParent.GotoElement(AId));
  result := nil;
end;

function TProcessBuilder.GotoElement(AElement: TFlowElement): TProcessBuilder;
begin
  if Assigned(FElement) then
    if FElement = AElement then
      exit(Self)
    else if Assigned(FParent) then
      exit(FParent.GotoElement(AElement));
  result := nil;
end;

function TProcessBuilder.GotoLastGateway: TProcessBuilder;
begin
  if Assigned(FElement) then
    if FElement is TGateway then
      exit(Self)
    else if Assigned(FParent) then
      exit(FParent.GotoLastGateway);
  result := nil;
end;

function TProcessBuilder.Id(AId: string): TProcessBuilder;
begin
  if Assigned(FElement) then
    FElement.Id := AId;
  result := Self;
end;

function TProcessBuilder.InclusiveGateway: TProcessBuilder;
begin
  result := BuildItem(AddNode(TInclusiveGateway.Create), true);
end;

function TProcessBuilder.LinkTo(ElementId: string): TProcessBuilder;
var
  node: TFlowNode;
begin
  node := FProcess.GetNode(ElementId);
  if Assigned(node) then
    result := BuildItem(node, true)
  else
    raise Exception.CreateFmt(SErrorElementNotFound, [ElementId]);
end;

function TProcessBuilder.LinkTo(ANode: TFlowNode): TProcessBuilder;
begin
  result := BuildItem(ANode, true);
end;

function TProcessBuilder.ParallelGateway: TProcessBuilder;
begin
  result := BuildItem(AddNode(TParallelGateway.Create), true);
end;

function TProcessBuilder.StartEvent: TProcessBuilder;
begin
  result := BuildItem(AddStartEvent, false);
end;

function TProcessBuilder.Variable(AName: string): TProcessBuilder;
begin
  result := Variable(AName, TValue.Empty);
end;

function TProcessBuilder.Variable(AName: string; ADefaultValue: TValue): TProcessBuilder;
begin
  AddVariable(AName, ADefaultValue);
  result := Self;
end;

function TProcessBuilder.AddStartEvent: TStartEvent;
begin
  result := TStartEvent.Create;
  FProcess.Nodes.Add(result);
end;

end.

