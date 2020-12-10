unit Octopus.Global;

interface

uses
  System.SysUtils;

type
  TUtils = class
  public
    class function NewId: string;
  end;

implementation

{ TUtils }

class function TUtils.NewId: string;
var
  S: string;
begin
  S := LowerCase(TGUID.NewGuid.ToString);
  S := Copy(S, 2, 8) + Copy(S, 11, 4) + Copy(S, 16, 4) + Copy(S, 21, 4) + Copy(S, 26, 12);
  Result := S;
end;

end.

