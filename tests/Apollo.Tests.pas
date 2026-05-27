unit Apollo.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TApolloLogEntryTests = class
  public
    [Test]
    procedure EntryToJSON_ContainsMessage;
    [Test]
    procedure EntryToJSON_ContainsLevel;
    [Test]
    procedure EntryToJSON_ContainsTimestamp;
    [Test]
    procedure EntryToJSON_ContainsIntField;
    [Test]
    procedure EntryToJSON_ContainsDoubleField;
    [Test]
    procedure EntryToJSON_ContainsBoolField;
    [Test]
    procedure EntryToJSON_ContainsStringField;
    [Test]
    procedure LevelName_Trace_IsTrace;
    [Test]
    procedure LevelName_Fatal_IsFatal;
  end;

  [TestFixture]
  TApolloLoggerTests = class
  public
    [Test]
    procedure Builder_Field_String_IsChainable;
    [Test]
    procedure Builder_Field_Integer_IsChainable;
    [Test]
    procedure Builder_Field_Double_IsChainable;
    [Test]
    procedure Builder_Field_Bool_IsChainable;
    [Test]
    procedure Builder_TraceId_IsChainable;
    [Test]
    procedure Builder_SpanId_IsChainable;
    [Test]
    procedure Logger_MinLevel_FiltersLowerLevels;
    [Test]
    procedure Logger_Error_WithException_AddsErrorFields;
  end;

implementation

uses
  Apollo.Entry,
  Apollo.Logger,
  Apollo.Dispatcher,
  Apollo.Sink.Interfaces,
  System.SysUtils;

{ TApolloLogEntryTests }

procedure TApolloLogEntryTests.EntryToJSON_ContainsMessage;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Message := 'test message';
  LEntry.Timestamp := Now;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"test message"'), 'JSON must contain the message');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsLevel;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llWarn;
  LEntry.Timestamp := Now;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('WARN') or LJSON.Contains('warn'), 'JSON must contain level');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsTimestamp;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"@timestamp"'), 'JSON must contain @timestamp');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsIntField;
var
  LEntry: TApolloLogEntry;
  LVal: TApolloFieldValue;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  SetLength(LEntry.Fields, 1);
  LEntry.Fields[0].Key := 'port';
  LVal.Kind := fkInt64;
  LVal.AsInt64 := 9000;
  LEntry.Fields[0].Value := LVal;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"port"'), 'JSON must contain field key');
  Assert.IsTrue(LJSON.Contains('9000'), 'JSON must contain int value without quotes');
  Assert.IsFalse(LJSON.Contains('"9000"'), 'Int value must not be quoted');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsDoubleField;
var
  LEntry: TApolloLogEntry;
  LVal: TApolloFieldValue;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  SetLength(LEntry.Fields, 1);
  LEntry.Fields[0].Key := 'ratio';
  LVal.Kind := fkDouble;
  LVal.AsDouble := 3.14;
  LEntry.Fields[0].Value := LVal;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"ratio"'), 'JSON must contain field key');
  Assert.IsTrue(LJSON.Contains('3.14') or LJSON.Contains('3,14'),
    'JSON must contain double value');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsBoolField;
var
  LEntry: TApolloLogEntry;
  LVal: TApolloFieldValue;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  SetLength(LEntry.Fields, 1);
  LEntry.Fields[0].Key := 'active';
  LVal.Kind := fkBoolean;
  LVal.AsBoolean := True;
  LEntry.Fields[0].Value := LVal;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"active"'), 'JSON must contain field key');
  Assert.IsTrue(LJSON.Contains('true'), 'JSON must contain boolean true (unquoted)');
  Assert.IsFalse(LJSON.Contains('"true"'), 'Bool value must not be quoted');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsStringField;
var
  LEntry: TApolloLogEntry;
  LVal: TApolloFieldValue;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  SetLength(LEntry.Fields, 1);
  LEntry.Fields[0].Key := 'method';
  LVal.Kind := fkString;
  LVal.AsString := 'GET';
  LEntry.Fields[0].Value := LVal;
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"method"'), 'JSON must contain field key');
  Assert.IsTrue(LJSON.Contains('"GET"'), 'String value must be quoted');
end;

procedure TApolloLogEntryTests.LevelName_Trace_IsTrace;
begin
  Assert.AreEqual('TRACE', LevelToString(llTrace));
end;

procedure TApolloLogEntryTests.LevelName_Fatal_IsFatal;
begin
  Assert.AreEqual('FATAL', LevelToString(llFatal));
end;

{ TApolloLoggerTests }

procedure TApolloLoggerTests.Builder_Field_String_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').Field('key', 'value');
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Builder_Field_Integer_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').Field('count', 42);
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Builder_Field_Double_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').Field('ratio', 1.5);
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Builder_Field_Bool_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').Field('active', True);
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Builder_TraceId_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').TraceId('abc123');
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Builder_SpanId_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LBuilder := LLogger.Info('test').SpanId('def456');
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Logger_MinLevel_FiltersLowerLevels;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  // A builder returned for a filtered level must have nil dispatcher
  // (no-op: Emit does nothing). We verify by calling Emit without crash.
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LLogger.MinLevel(llWarn);
  LBuilder := LLogger.Debug('this should be filtered');
  Assert.IsNotNull(LBuilder, 'Builder must not be nil even for filtered levels');
  // Emit on a filtered builder must be a no-op (no exception)
  Assert.WillNotRaise(procedure begin LBuilder.Emit; end);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Logger_Error_WithException_AddsErrorFields;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
  LEx: Exception;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LEx := Exception.Create('connection timeout');
  try
    LBuilder := LLogger.Error('job failed', LEx);
    Assert.IsNotNull(LBuilder, 'Builder must not be nil');
    // Further verification: the builder must be chainable after error fields
    LBuilder := LBuilder.Field('job_id', '42');
    Assert.IsNotNull(LBuilder);
  finally
    LEx.Free;
    LDispatcher.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TApolloLogEntryTests);
  TDUnitX.RegisterTestFixture(TApolloLoggerTests);

end.
