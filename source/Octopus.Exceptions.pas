unit Octopus.Exceptions;

interface

uses
  System.SysUtils;

type
  EOctopusException = class(Exception)
  end;

  EOctopusDefinitionNotFound = class(EOctopusException)
  public
    constructor Create(const ProcessId: string);
  end;

  EOctopusNodeNotFound = class(EOctopusException)
  public
    constructor Create(const NodeId: string);
  end;

  EOctopusTransitionNotFound = class(EOctopusException)
  public
    constructor Create(const TransitionId: string);
  end;

  EOctopusElementNotFound = class(EOctopusException)
  public
    constructor Create(const ElementId: string);
  end;

implementation

uses
  Octopus.Resources;

{ EOctopusProcessNotFound }

constructor EOctopusDefinitionNotFound.Create(const ProcessId: string);
begin
  inherited CreateFmt(SErrorDefinitionNotFound, [ProcessId]);
end;

{ EOctopusTransitionNotFound }

constructor EOctopusTransitionNotFound.Create(const TransitionId: string);
begin
  inherited CreateFmt(SErrorTransitionNotFound, [TransitionId]);
end;

{ EOctopusNodeNotFound }

constructor EOctopusNodeNotFound.Create(const NodeId: string);
begin
  inherited CreateFmt(SErrorNodeNotFound, [NodeId]);
end;

{ EOctopusElementNotFound }

constructor EOctopusElementNotFound.Create(const ElementId: string);
begin
  inherited CreateFmt(SErrorElementNotFound, [ElementId]);
end;

end.
