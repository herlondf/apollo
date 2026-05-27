unit Apollo.Dispatcher;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloDispatcher = class
  private
    FQueue: TThreadedQueue<TApolloLogEntry>;
    FSinks: TList<IApolloSink>;
    FThread: TThread;
    FFlushIntervalMs: Integer;
    FBatchSize: Integer;
    FRunning: Boolean;
    procedure FlushBatch(const ABatch: TArray<TApolloLogEntry>);
  public
    class function New(const AFlushIntervalMs: Integer = 500;
      const ABatchSize: Integer = 100): TApolloDispatcher;
    constructor Create(const AFlushIntervalMs: Integer = 500;
      const ABatchSize: Integer = 100);
    destructor Destroy; override;
    procedure AddSink(const ASink: IApolloSink);
    procedure Enqueue(const AEntry: TApolloLogEntry);
    procedure Start;
    procedure Stop;
  end;

implementation

{ TApolloDispatcher }

class function TApolloDispatcher.New(const AFlushIntervalMs: Integer;
  const ABatchSize: Integer): TApolloDispatcher;
begin
  Result := TApolloDispatcher.Create(AFlushIntervalMs, ABatchSize);
end;

constructor TApolloDispatcher.Create(const AFlushIntervalMs: Integer;
  const ABatchSize: Integer);
begin
  inherited Create;
  FFlushIntervalMs := AFlushIntervalMs;
  FBatchSize := ABatchSize;
  FRunning := False;
  FQueue := TThreadedQueue<TApolloLogEntry>.Create(10000, 100, 0);
  FSinks := TList<IApolloSink>.Create;
end;

destructor TApolloDispatcher.Destroy;
begin
  if FRunning then
    Stop;
  FSinks.Free;
  FQueue.Free;
  inherited;
end;

procedure TApolloDispatcher.AddSink(const ASink: IApolloSink);
begin
  FSinks.Add(ASink);
end;

procedure TApolloDispatcher.Enqueue(const AEntry: TApolloLogEntry);
begin
  FQueue.PushItem(AEntry);
end;

procedure TApolloDispatcher.FlushBatch(const ABatch: TArray<TApolloLogEntry>);

  function FilterForSink(const ASink: IApolloSink): TArray<TApolloLogEntry>;
  var
    LResult: TArray<TApolloLogEntry>;
    LCount: Integer;
    LEntry: TApolloLogEntry;
  begin
    LCount := 0;
    SetLength(LResult, Length(ABatch));
    for LEntry in ABatch do
    begin
      if Ord(LEntry.Level) >= Ord(ASink.MinLevel) then
      begin
        LResult[LCount] := LEntry;
        Inc(LCount);
      end;
    end;
    SetLength(LResult, LCount);
    Result := LResult;
  end;

  function MakeSinkTask(const ASink: IApolloSink;
    const AFiltered: TArray<TApolloLogEntry>): ITask;
  var
    LCaptureSink: IApolloSink;
    LCaptureFiltered: TArray<TApolloLogEntry>;
  begin
    LCaptureSink := ASink;
    LCaptureFiltered := AFiltered;
    Result := TTask.Run(
      procedure
      begin
        LCaptureSink.Write(LCaptureFiltered);
      end
    );
  end;

var
  LTasks: TArray<ITask>;
  LIdx: Integer;
  LSink: IApolloSink;
  LFiltered: TArray<TApolloLogEntry>;
begin
  if Length(ABatch) = 0 then
    Exit;

  SetLength(LTasks, FSinks.Count);
  for LIdx := 0 to FSinks.Count - 1 do
  begin
    LSink := FSinks[LIdx];
    LFiltered := FilterForSink(LSink);
    if Length(LFiltered) > 0 then
      LTasks[LIdx] := MakeSinkTask(LSink, LFiltered)
    else
      LTasks[LIdx] := nil;
  end;

  for LIdx := 0 to High(LTasks) do
    if LTasks[LIdx] <> nil then
      LTasks[LIdx].Wait;
end;

procedure TApolloDispatcher.Start;
var
  LSelf: TApolloDispatcher;
begin
  FRunning := True;
  LSelf := Self;
  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      LEntry: TApolloLogEntry;
      LBatch: TArray<TApolloLogEntry>;
      LBatchCount: Integer;
      LWait: TWaitResult;
    begin
      while LSelf.FRunning do
      begin
        LBatchCount := 0;
        SetLength(LBatch, LSelf.FBatchSize);

        LWait := LSelf.FQueue.PopItem(LEntry, LSelf.FFlushIntervalMs);
        if LWait = wrSignaled then
        begin
          LBatch[LBatchCount] := LEntry;
          Inc(LBatchCount);

          while (LBatchCount < LSelf.FBatchSize) and
                (LSelf.FQueue.PopItem(LEntry, 0) = wrSignaled) do
          begin
            LBatch[LBatchCount] := LEntry;
            Inc(LBatchCount);
          end;
        end;

        if LBatchCount > 0 then
        begin
          SetLength(LBatch, LBatchCount);
          LSelf.FlushBatch(LBatch);
        end;
      end;

      // Final flush on stop
      LBatchCount := 0;
      SetLength(LBatch, LSelf.FBatchSize);
      while LSelf.FQueue.PopItem(LEntry, 0) = wrSignaled do
      begin
        LBatch[LBatchCount] := LEntry;
        Inc(LBatchCount);
        if LBatchCount >= LSelf.FBatchSize then
        begin
          SetLength(LBatch, LBatchCount);
          LSelf.FlushBatch(LBatch);
          LBatchCount := 0;
          SetLength(LBatch, LSelf.FBatchSize);
        end;
      end;
      if LBatchCount > 0 then
      begin
        SetLength(LBatch, LBatchCount);
        LSelf.FlushBatch(LBatch);
      end;
    end
  );
  FThread.FreeOnTerminate := False;
  FThread.Start;
end;

procedure TApolloDispatcher.Stop;
begin
  FRunning := False;
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
end;

end.
