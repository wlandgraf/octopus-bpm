unit BusinessObjects;

interface

uses
  Octopus.Process,
  Octopus.Process.Activities;

type
  TYoungPersonCondition = class(TCondition)
  public
    function Evaluate(Context: TTransitionExecutionContext): Boolean; override;
  end;

  TWriteLnActivity = class(TActivity)
  strict private
    [Persistent]
    FMsg: string;
  public
    constructor Create(const Msg: string); reintroduce;
    procedure ExecuteInstance(Context: TActivityExecutionContext); override;
  end;

implementation

{ TWriteLnActivity }

constructor TWriteLnActivity.Create(const Msg: string);
begin
  inherited Create;
  FMsg := Msg;
end;

procedure TWriteLnActivity.ExecuteInstance(Context: TActivityExecutionContext);
begin
  WriteLn(FMsg);
end;

{ TYoungPersonCondition }

function TYoungPersonCondition.Evaluate(Context: TTransitionExecutionContext): Boolean;
begin
  Result := Context.GetVariable('age').AsInteger <= 90;
end;

end.
