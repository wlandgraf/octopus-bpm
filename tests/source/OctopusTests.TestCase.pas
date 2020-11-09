unit OctopusTests.TestCase;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  {$IFDEF USE_BIZ}
  BizTest.Framework,
  BizTest.TestCase,
  {$ELSE}
  TestFramework,
  {$ENDIF}
  Octopus.Process,
  Octopus.Process.Builder,
  Octopus.Process.Activities,
  Octopus.Engine.Runner;

type
  {$IFNDEF USE_BIZ}
  TBizTestCase = TTestCase;
  TBizTestCaseClass = class of TTestCase;
  {$ENDIF}

  TOctopusTestCase = class;

  TRunAssertionProc = reference to procedure(Status: TRunnerStatus; Instance: IProcessInstanceData);

  TOctopusTestCase = class(TBizTestCase)
  private
    FProcess: TWorkflowProcess;
    FBuilder: TProcessBuilder;
  protected
    function RunInstance(Instance: IProcessInstanceData): TRunnerStatus;
    procedure RunProcess(AssertionProc: TRunAssertionProc); overload;
    procedure RunProcess(ExpectedStatus: TRunnerStatus; ExpectedTokens: integer = -1); overload;
    property Process: TWorkflowProcess read FProcess;
    property Builder: TProcessBuilder read FBuilder;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;

procedure RegisterOctopusTest(ATestClass: TBizTestCaseClass);

implementation

uses
  MemoryInstanceData;

procedure RegisterOctopusTest(ATestClass: TBizTestCaseClass);
begin
  RegisterTest('Octopus', ATestClass.Suite);
end;

{ TOctopusTestCase }

function TOctopusTestCase.RunInstance(Instance: IProcessInstanceData): TRunnerStatus;
var
  runner: TWorkflowRunner;
begin
  runner := TWorkflowRunner.Create(Process, Instance);
  try
    runner.Execute;
    result := runner.Status;
  finally
    runner.Free;
  end;
end;

procedure TOctopusTestCase.RunProcess(AssertionProc: TRunAssertionProc);
var
  instance: TMemoryInstanceData;
begin
  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);
    AssertionProc(RunInstance(instance), Instance);
  finally
    instance.Free;
  end;
end;

procedure TOctopusTestCase.RunProcess(ExpectedStatus: TRunnerStatus; ExpectedTokens: integer);
begin
  RunProcess(
    procedure(Status: TRunnerStatus; Instance: IProcessInstanceData)
    begin
      CheckEquals(Ord(ExpectedStatus), Ord(Status));
      if ExpectedTokens >= 0 then
        CheckEquals(ExpectedTokens, instance.CountTokens);
    end
  );
end;

procedure TOctopusTestCase.Setup;
begin
  FProcess := TWorkflowProcess.Create;
  FBuilder := TProcessBuilder.Create(FProcess);
end;

procedure TOctopusTestCase.TearDown;
begin
  FProcess.Free;
  FBuilder.Free;
end;

end.

