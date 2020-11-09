unit OctopusTests.Cases.AbstractTask;

interface

uses
  System.SysUtils,
  System.Rtti,
  Generics.Collections,
  OctopusTests.TestCase,
  Octopus.Process,
  Octopus.Activities.Task;

type
  TTestAbstractTask = class;

  TTestAbstractTask = class(TOctopusTestCase)
  public
    procedure SetUp; override;
  published
    procedure SimpleTask;
    procedure TaskEvaluateStatus;
    procedure TaskEvaluateStatusLater;
  end;

  TTestTaskActivity = class(TTaskActivity)
  protected
    function CreateTask: string; override;
    procedure GetTaskData(TaskId: string; Proc: TProc<string,TValue>); override;
    function TaskExists(TaskId: string): boolean; override;
    function TaskFinished(TaskId: string): boolean; override;
  end;

  TTestTaskInstance = class
    CreatedOn: TDateTime;
    Status: string;
  end;

  TTestTaskDB = class
  private
    class var
      FTasks: TObjectList<TTestTaskInstance>;
  public
    class constructor Create;
    class destructor Destroy;
    class property Tasks: TObjectList<TTestTaskInstance> read FTasks;
  end;

implementation

uses
  MemoryInstanceData;

{ TTestAbstractTask }

procedure TTestAbstractTask.Setup;
begin
  inherited;
  TTestTaskDB.Tasks.Clear;
end;

procedure TTestAbstractTask.SimpleTask;
var
  instance: TMemoryInstanceData;
begin
  Builder
    .StartEvent
    .Activity(TTestTaskActivity)
    .EndEvent;

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals(1, TTestTaskDB.Tasks.Count); // new task

    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals(1, TTestTaskDB.Tasks.Count); // same task (waiting)

    TTestTaskDB.Tasks[0].Status := 'closed';
    RunInstance(instance);
    CheckEquals(0, instance.CountTokens); // finished
  finally
    instance.Free;
  end;
end;

procedure TTestAbstractTask.TaskEvaluateStatus;
var
  instance: TMemoryInstanceData;
begin
  Builder
    .StartEvent
    .Activity(TTestTaskActivity).Id('check')
    .Condition(
      function(Context: TExecutionContext): boolean
      begin
        result := Context.LastData('status').AsString = 'approved';
      end)
    .Activity(TTestTaskActivity).Id('approved')
    .GotoElement('check')
    .Condition(
      function(Context: TExecutionContext): boolean
      begin
        result := Context.LastData('status').AsString = 'rejected';
      end)
    .Activity(TTestTaskActivity).Id('rejected');

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals(1, TTestTaskDB.Tasks.Count); // new task

    TTestTaskDB.Tasks[0].Status := 'rejected';

    RunInstance(instance);
    CheckEquals(2, TTestTaskDB.Tasks.Count); // new task (rejected)
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals('rejected', instance.GetTokens[0].Node.Id);
  finally
    instance.Free;
  end;
end;

procedure TTestAbstractTask.TaskEvaluateStatusLater;
var
  instance: TMemoryInstanceData;
begin
  Builder
    .StartEvent
    .Activity(TTestTaskActivity).Id('checktask')
    .ExclusiveGateway.Id('decision')
    .Condition(
      function(Context: TExecutionContext): boolean
      begin
        result := Context.LastData('checktask', 'status').AsString = 'approved';
      end)
    .Activity(TTestTaskActivity).Id('approved')
    .GotoElement('decision')
    .Condition(
      function(Context: TExecutionContext): boolean
      begin
        result := Context.LastData('checktask', 'status').AsString = 'rejected';
      end)
    .Activity(TTestTaskActivity).Id('rejected');

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals(1, TTestTaskDB.Tasks.Count); // new task

    TTestTaskDB.Tasks[0].Status := 'rejected';

    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals(2, TTestTaskDB.Tasks.Count); // new task (rejected)
    CheckEquals('rejected', instance.GetTokens[0].Node.Id);
  finally
    instance.Free;
  end;
end;

{ TTestTaskDB }

class constructor TTestTaskDB.Create;
begin
  FTasks := TObjectList<TTestTaskInstance>.Create;
end;

class destructor TTestTaskDB.Destroy;
begin
  FTasks.Free;
end;

{ TTestTaskActivity }

function TTestTaskActivity.CreateTask: string;
var
  task: TTestTaskInstance;
begin
  inherited;
  task := TTestTaskInstance.Create;
  task.CreatedOn := Now;
  task.Status := 'open';
  result := IntToStr(TTestTaskDB.Tasks.Add(task));
end;

procedure TTestTaskActivity.GetTaskData(TaskId: string; Proc: TProc<string, TValue>);
var
  task: TTestTaskInstance;
begin
  task := TTestTaskDB.Tasks[StrToInt(TaskId)];
  Proc('CreatedOn', task.CreatedOn);
  Proc('Status', task.Status);
end;

function TTestTaskActivity.TaskExists(TaskId: string): boolean;
var
  itask: integer;
begin
  itask := StrToIntDef(TaskId, -1);
  result := (itask >= 0) and (itask < TTestTaskDB.Tasks.Count);
end;

function TTestTaskActivity.TaskFinished(TaskId: string): boolean;
var
  task: TTestTaskInstance;
begin
  task := TTestTaskDB.Tasks[StrToInt(TaskId)];
  result := task.Status <> 'open';
end;

initialization
  RegisterOctopusTest(TTestAbstractTask);
end.

