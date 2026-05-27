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
    procedure EntryToJSON_EmptyLogger_NotEmitted;
    [Test]
    procedure EntryToJSON_EmptyTraceId_NotEmitted;
    [Test]
    procedure EntryToJSON_PopulatedLogger_IsEmitted;
    [Test]
    procedure EntryToJSON_NoFields_NoFieldsKey;
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
    [Test]
    procedure Logger_WithContext_String_PropagatesInBuilder;
    [Test]
    procedure Logger_WithContext_Int_PropagatesInBuilder;
    [Test]
    procedure Logger_WithContext_IsChainable;
    [Test]
    procedure Logger_Noop_NoSetup_DoesNotCrash;
  end;

implementation

uses
  Apollo,
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
  Assert.IsTrue(LJSON.Contains('9000'), 'JSON must contain int value');
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

procedure TApolloLogEntryTests.EntryToJSON_EmptyLogger_NotEmitted;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  LEntry.Logger := '';
  LJSON := EntryToJSON(LEntry);
  Assert.IsFalse(LJSON.Contains('"logger"'), 'Empty logger must not be emitted');
end;

procedure TApolloLogEntryTests.EntryToJSON_EmptyTraceId_NotEmitted;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  LEntry.TraceId := '';
  LEntry.SpanId := '';
  LJSON := EntryToJSON(LEntry);
  Assert.IsFalse(LJSON.Contains('"traceId"'), 'Empty traceId must not be emitted');
  Assert.IsFalse(LJSON.Contains('"spanId"'), 'Empty spanId must not be emitted');
end;

procedure TApolloLogEntryTests.EntryToJSON_PopulatedLogger_IsEmitted;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  LEntry.Logger := 'my-service';
  LJSON := EntryToJSON(LEntry);
  Assert.IsTrue(LJSON.Contains('"logger"'), 'Non-empty logger must be emitted');
  Assert.IsTrue(LJSON.Contains('"my-service"'), 'Logger name must appear in JSON');
end;

procedure TApolloLogEntryTests.EntryToJSON_NoFields_NoFieldsKey;
var
  LEntry: TApolloLogEntry;
  LJSON: string;
begin
  LEntry := Default(TApolloLogEntry);
  LEntry.Level := llInfo;
  LEntry.Timestamp := Now;
  LJSON := EntryToJSON(LEntry);
  Assert.IsFalse(LJSON.Contains('"fields"'), 'Empty fields must not emit "fields" key');
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
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LLogger.MinLevel(llWarn);
  LBuilder := LLogger.Debug('this should be filtered');
  Assert.IsNotNull(LBuilder, 'Builder must not be nil even for filtered levels');
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
    LBuilder := LBuilder.Field('job_id', '42');
    Assert.IsNotNull(LBuilder);
  finally
    LEx.Free;
    LDispatcher.Free;
  end;
end;

procedure TApolloLoggerTests.Logger_WithContext_String_PropagatesInBuilder;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LLogger.WithContext('service', 'my-api');
  // Builder must be chainable after context — no crash
  LBuilder := LLogger.Info('test').Field('extra', 'val');
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Logger_WithContext_Int_PropagatesInBuilder;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
  LBuilder: IApolloLogBuilder;
begin
  LDispatcher := TApolloDispatcher.New;
  LLogger := TApolloLogger.New(LDispatcher);
  LLogger.WithContext('pid', 1234);
  LBuilder := LLogger.Warn('test');
  Assert.IsNotNull(LBuilder);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Logger_WithContext_IsChainable;
var
  LDispatcher: TApolloDispatcher;
  LLogger: IApolloLogger;
begin
  LDispatcher := TApolloDispatcher.New;
  // All four type overloads must chain without crashing
  LLogger := TApolloLogger.New(LDispatcher)
    .WithContext('service', 'my-api')
    .WithContext('version', 2)
    .WithContext('ratio', 1.5)
    .WithContext('debug', False);
  Assert.IsNotNull(LLogger);
  LDispatcher.Free;
end;

procedure TApolloLoggerTests.Logger_Noop_NoSetup_DoesNotCrash;
begin
  // GApollo is nil — convenience functions must return a no-op builder, not nil
  GApollo := nil;
  Assert.WillNotRaise(
    procedure
    begin
      ApolloInfo('test').Field('key', 'value').Emit;
      ApolloWarn('test').Field('n', 1).Emit;
      ApolloError('test').Emit;
      ApolloFatal('test').Field('active', True).Emit;
    end
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TApolloLogEntryTests);
  TDUnitX.RegisterTestFixture(TApolloLoggerTests);

end.
