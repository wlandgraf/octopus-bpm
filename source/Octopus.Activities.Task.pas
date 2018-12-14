unit Octopus.Activities.Task;

interface

uses
  System.Rtti,
  System.SysUtils,
  Octopus.Process.Activities;

type
  TTaskActivity = class abstract(TActivity)
  protected
    function CreateTask: string; virtual; abstract;
    procedure GetTaskData(TaskId: string; Proc: TProc<string,TValue>); virtual; abstract;
    function TaskExists(TaskId: string): boolean; virtual; abstract;
    function TaskFinished(TaskId: string): boolean; virtual; abstract;
  public
    procedure ExecuteInstance(Context: TActivityExecutionContext); override;
  end;

implementation

{ TTaskActivity }

procedure TTaskActivity.ExecuteInstance(Context: TActivityExecutionContext);
var
  taskId: string;
begin
  taskId := Context.GetLocalVariable('taskId').AsString;

  // create task instance if it does not exist
  if not TaskExists(taskId) then
  begin
    taskId := CreateTask;
    Context.SetLocalVariable('taskId', taskId);
  end;

  // task finished (flow)
  Context.Done := TaskFinished(taskId);

  if Context.Done then
  begin
    GetTaskData(taskId,
      procedure(Name: string; Value: TValue)
      begin
        Context.SetLocalVariable(Name, Value);
      end);
  end;
end;

end.

