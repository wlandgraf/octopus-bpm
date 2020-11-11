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

implementation

uses
  Octopus.Resources;

{ EOctopusProcessNotFound }

constructor EOctopusDefinitionNotFound.Create(const ProcessId: string);
begin
  inherited CreateFmt(SErrorDefinitionNotFound, [ProcessId]);
end;

end.
