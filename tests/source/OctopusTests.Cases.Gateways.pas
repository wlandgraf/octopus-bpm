unit OctopusTests.Cases.Gateways;

interface

uses
  Generics.Collections,
  OctopusTests.TestCase,
  Octopus.Process,
  Octopus.Process.Activities,
  Octopus.Engine.Runner;

type
  TTestGateways = class(TOctopusTestCase)
  private
    function AlwaysTrue(Context: TExecutionContext): boolean;
    function AlwaysFalse(Context: TExecutionContext): boolean;
  published
    procedure Exclusive;
    procedure ExclusiveCondition;
    procedure ExclusiveLoop;
    procedure Parallel;
    procedure ParallelCondition;
    procedure ParallelMerge;
    procedure InclusiveCondition;
    procedure InclusiveMerge;
  end;

implementation

uses
  OctopusTests.Utils,
  MemoryInstanceData;

{ TTestGateways }

function TTestGateways.AlwaysFalse(Context: TExecutionContext): boolean;
begin
  result := false;
end;

function TTestGateways.AlwaysTrue(Context: TExecutionContext): boolean;
begin
  result := true;
end;

procedure TTestGateways.Exclusive;
begin
  { (start) --> <gateway> --> [test]
                    |
                    +-------> [test] }
  Builder
    .StartEvent
    .ExclusiveGateway
      .Activity(TTestUtils.PersistedActivity)
    .GotoLastGateway
      .Activity(TTestUtils.PersistedActivity);

  RunProcess(TRunnerStatus.Processed, 1);
end;

procedure TTestGateways.ExclusiveCondition;
begin
  { (start) --> <gateway> --false--> [falseval]
                    |
                    +-------true---> [trueval] }
  Builder
    .StartEvent
    .ExclusiveGateway
      .Condition(AlwaysFalse)
      .Activity(TTestUtils.PersistedActivity).Id('falseval')
    .GotoLastGateway
      .Condition(AlwaysTrue)
      .Activity(TTestUtils.PersistedActivity).Id('trueval');

  RunProcess(
    procedure(Status: TRunnerStatus; Instance: IProcessInstanceData)
    begin
      CheckEquals(1, Instance.CountTokens);
      CheckEquals('trueval', Instance.GetTokens[0].Node.Id);
    end
  );
end;

procedure TTestGateways.ExclusiveLoop;
begin
  {                             +--loop>10--> (end)
                                |
    (start) --> [init] -->  <gateway> --loop<=10--> [increment]
                                ^                         |
                                |                         |
                                +-------------------------+
  }

  Builder
    .Variable('loop')
    .StartEvent
    // variable initialization
    .Activity(TAnonymousActivity.Create(
      procedure(Context: TActivityExecutionContext)
      begin
        Context.SetVariable('loop', 0);
        Context.Done := true;
      end)
    )
    .ExclusiveGateway.Id('gateway')
      // loop > 10? finish
      .Condition(
        function(Context: TExecutionContext): boolean
        begin
          result := Context.Instance.GetVariable('loop').AsInteger > 10;
        end
      )
      .EndEvent
    .GotoLastGateway
      // loop <= 10? increment and back to the gateway
      .Condition(
        function(Context: TExecutionContext): boolean
        begin
          result := Context.Instance.GetVariable('loop').AsInteger <= 10;
        end
      )
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        var
          loop: integer;
        begin
          loop := Context.GetVariable('loop').AsInteger;
          Context.SetVariable('loop', loop + 1);
          Context.Done := true;
        end)
      )
      .LinkTo('gateway');

  RunProcess(
    procedure(Status: TRunnerStatus; Instance: IProcessInstanceData)
    begin
      CheckEquals(11, Instance.GetVariable('loop').AsInteger);
    end
  );
end;

procedure TTestGateways.InclusiveCondition;
begin
  {
                    +------true----> [test]
                    |
    (start) --> <gateway> --false--> [test]
                    |
                    +------true----> [test]
  }

  Builder
    .StartEvent
    .InclusiveGateway
      .Condition(AlwaysTrue)
      .Activity(TTestUtils.PersistedActivity)
    .GotoLastGateway
      .Condition(AlwaysFalse)
      .Activity(TTestUtils.PersistedActivity)
    .GotoLastGateway
      .Condition(AlwaysTrue)
      .Activity(TTestUtils.PersistedActivity);

  RunProcess(TRunnerStatus.Processed, 2);
end;

procedure TTestGateways.InclusiveMerge;
var
  instance: TMemoryInstanceData;
  token: TToken;
  tokens: TArray<TToken>;
begin
  {                                       +----not finish---+
                                          |                 |
                                          v                 |
    (start) --> <parallel-gateway> --> [act1] --> <inclusive-gateway> --finish--> (end)
                         |                                  ^
                         |                                  |
                         +-----------> [act2] --------------+
  }

  Builder
    .Variable('done1', false)
    .Variable('done2', false)
    .Variable('finish', false)
    .StartEvent
    .ParallelGateway.Id('par')
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          Context.Done := Context.GetVariable('done1').AsBoolean;
        end)
      ).Id('act1')
      .InclusiveGateway.Id('inc')
        .Condition(
          function(Context: TExecutionContext): boolean
          begin
            result := Context.Instance.GetVariable('finish').AsBoolean;
          end
        )
        .EndEvent
      .GotoLastGateway // inclusive gateway
        .Condition(
          function(Context: TExecutionContext): boolean
          begin
            result := not Context.Instance.GetVariable('finish').AsBoolean;
          end
        )
        .LinkTo('act1')
    .GotoElement('par') // parallel gateway
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          Context.Done := Context.GetVariable('done2').AsBoolean;
        end)
      ).Id('act2')
      .LinkTo('inc'); // inclusive gateway

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);

    // run #1: two parallel activities
    RunInstance(instance);
    CheckEquals(2, instance.CountTokens);
    tokens := instance.GetTokens;
    Check(tokens[0].Transition <> tokens[1].Transition, 'transitions not equal');

    // run #2: act1 done, inclusive gateway must wait for act2
    instance.SetVariable('done1', true);
    RunInstance(instance);
    CheckEquals(2, instance.CountTokens);
    tokens := instance.GetTokens;
    for token in tokens do
      Check((token.Node.Id = 'act2') or (token.Node.Id = 'inc'));

    // run #3: act2 done, inclusive gateway must trigger and back to act1
    instance.SetVariable('done1', false);
    instance.SetVariable('done2', true);
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens); // running
    CheckEquals('act1', instance.GetTokens[0].Node.Id);

    // run #4: act1 done, inclusive gateway must trigger (nothing to wait) and finish
    instance.SetVariable('done1', true);
    instance.SetVariable('finish', true);
    RunInstance(instance);
    CheckEquals(0, instance.CountTokens); // finished
  finally
    instance.Free;
  end;
end;

procedure TTestGateways.Parallel;
begin
  {
    (start) --> <gateway> --> [activity]
                    |
                    +-------> [activity]
  }

  Builder
    .StartEvent
    .ParallelGateway
      .Activity(TTestUtils.PersistedActivity)
    .GotoLastGateway
      .Activity(TTestUtils.PersistedActivity);

  RunProcess(TRunnerStatus.Processed, 2);
end;

procedure TTestGateways.ParallelCondition;
begin
  {
    (start) --> <gateway> --true-> [activity]
                    |
                    +------false-> [activity]
  }

  Builder
    .StartEvent
    .ParallelGateway
      .Condition(AlwaysTrue)
      .Activity(TTestUtils.PersistedActivity)
    .GotoLastGateway
      .Condition(AlwaysFalse)
      .Activity(TTestUtils.PersistedActivity);

  RunProcess(TRunnerStatus.Processed, 2);
end;

procedure TTestGateways.ParallelMerge;
var
  instance: TMemoryInstanceData;
  token: TToken;
  tokens: TArray<TToken>;
begin
  {
    (start) --> <gateway> --> [act1] --> <gateway> --> [last] -> (end)
                    |                        ^
                    |                        |
                    +-------> [act2] --------+
  }

  Builder
    .Variable('done1', false)
    .Variable('done2', false)
    .StartEvent
    .ParallelGateway.Id('fork')
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          Context.Done := Context.GetVariable('done1').AsBoolean;
        end)
      ).Id('act1')
      .ParallelGateway.Id('merge')
      .Activity(TTestUtils.PersistedActivity).Id('last')
      .EndEvent
    .GotoElement('fork')
      .Activity(TAnonymousActivity.Create(
        procedure(Context: TActivityExecutionContext)
        begin
          Context.Done := Context.GetVariable('done2').AsBoolean;
        end)
      ).Id('act2')
      .LinkTo('merge');

  instance := TMemoryInstanceData.Create;
  try
    instance.StartInstance(Process);

    // run #1: two parallel activities
    RunInstance(instance);
    CheckEquals(2, instance.CountTokens); // running

    // run #2: act1 done, parallel gateway must wait for act2
    instance.SetVariable('done1', true);
    RunInstance(instance);
    CheckEquals(2, instance.CountTokens);
    tokens := instance.GetTokens;
    for token in tokens do
      Check((token.Node.Id = 'act2') or (token.Node.Id = 'merge'));

    // run #3: act2 done, parallel gateway must trigger
    instance.SetVariable('done2', true);
    RunInstance(instance);
    CheckEquals(1, instance.CountTokens);
    CheckEquals('last', instance.GetTokens[0].Node.Id);
  finally
    instance.Free;
  end;
end;

initialization
  RegisterOctopusTest(TTestGateways);
end.

