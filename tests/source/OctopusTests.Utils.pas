unit OctopusTests.Utils;

interface

uses
  Octopus.Process,
  Octopus.Process.Activities;

type
  TTestUtils = class
  public
    class function PersistedActivity: TActivity;
  end;

implementation

{ TTestUtils }

class function TTestUtils.PersistedActivity: TActivity;
begin
  result := TAnonymousActivity.Create(
    procedure(Context: TActivityExecutionContext)
    begin
      Context.Done := false;
    end
  );
end;

end.
