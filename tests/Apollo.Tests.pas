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
    procedure EntryToJSON_ContainsFields;
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
    procedure Builder_TraceId_IsChainable;
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
  Entry: TApolloLogEntry;
  JSON: string;
begin
  Entry := Default(TApolloLogEntry);
  Entry.Level := llInfo;
  Entry.Message := 'test message';
  Entry.Timestamp := Now;
  JSON := EntryToJSON(Entry);
  Assert.IsTrue(JSON.Contains('"test message"'), 'JSON must contain the message');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsLevel;
var
  Entry: TApolloLogEntry;
  JSON: string;
begin
  Entry := Default(TApolloLogEntry);
  Entry.Level := llWarn;
  Entry.Timestamp := Now;
  JSON := EntryToJSON(Entry);
  Assert.IsTrue(JSON.Contains('WARN') or JSON.Contains('warn'), 'JSON must contain level');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsTimestamp;
var
  Entry: TApolloLogEntry;
  JSON: string;
begin
  Entry := Default(TApolloLogEntry);
  Entry.Level := llInfo;
  Entry.Timestamp := Now;
  JSON := EntryToJSON(Entry);
  Assert.IsTrue(JSON.Contains('"timestamp"') or JSON.Contains('"time"'), 'JSON must contain timestamp');
end;

procedure TApolloLogEntryTests.EntryToJSON_ContainsFields;
var
  Entry: TApolloLogEntry;
  JSON: string;
begin
  Entry := Default(TApolloLogEntry);
  Entry.Level := llInfo;
  Entry.Timestamp := Now;
  SetLength(Entry.Fields, 1);
  Entry.Fields[0].Key := 'port';
  Entry.Fields[0].Value := '9000';
  JSON := EntryToJSON(Entry);
  Assert.IsTrue(JSON.Contains('port'), 'JSON must contain field key');
  Assert.IsTrue(JSON.Contains('9000'), 'JSON must contain field value');
end;

procedure TApolloLogEntryTests.LevelName_Trace_IsTrace;
begin
  Assert.AreEqual('TRACE', LevelName(llTrace));
end;

procedure TApolloLogEntryTests.LevelName_Fatal_IsFatal;
begin
  Assert.AreEqual('FATAL', LevelName(llFatal));
end;

{ TApolloLoggerTests }

procedure TApolloLoggerTests.Builder_Field_String_IsChainable;
var
  Dispatcher: TApolloDispatcher;
  Logger: IApolloLogger;
  Builder: IApolloLogBuilder;
begin
  Dispatcher := TApolloDispatcher.New;
  Logger := TApolloLoggerImpl.New(Dispatcher, 'test');
  Builder := Logger.Info('test').Field('key', 'value');
  Assert.IsNotNull(Builder);
end;

procedure TApolloLoggerTests.Builder_Field_Integer_IsChainable;
var
  Dispatcher: TApolloDispatcher;
  Logger: IApolloLogger;
  Builder: IApolloLogBuilder;
begin
  Dispatcher := TApolloDispatcher.New;
  Logger := TApolloLoggerImpl.New(Dispatcher, 'test');
  Builder := Logger.Info('test').Field('count', 42);
  Assert.IsNotNull(Builder);
end;

procedure TApolloLoggerTests.Builder_TraceId_IsChainable;
var
  Dispatcher: TApolloDispatcher;
  Logger: IApolloLogger;
  Builder: IApolloLogBuilder;
begin
  Dispatcher := TApolloDispatcher.New;
  Logger := TApolloLoggerImpl.New(Dispatcher, 'test');
  Builder := Logger.Info('test').TraceId('abc123');
  Assert.IsNotNull(Builder);
end;

initialization
  TDUnitX.RegisterTestFixture(TApolloLogEntryTests);
  TDUnitX.RegisterTestFixture(TApolloLoggerTests);

end.
