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
begin
  result := TGUID.NewGuid.ToString;
  result := Copy(result, 2, Length(result) - 2);
end;

end.

