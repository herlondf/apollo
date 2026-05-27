unit Apollo.Logger;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Apollo.Entry,
  Apollo.Dispatcher;

type
  IApolloLogBuilder = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function Field(const AKey, AValue: string): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Integer): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Double): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Boolean): IApolloLogBuilder; overload;
    function TraceId(const AId: string): IApolloLogBuilder;
    function SpanId(const AId: string): IApolloLogBuilder;
    procedure Emit;
  end;

  IApolloLogger = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Trace(const AMessage: string): IApolloLogBuilder;
    function Debug(const AMessage: string): IApolloLogBuilder;
    function Info(const AMessage: string): IApolloLogBuilder;
    function Warn(const AMessage: string): IApolloLogBuilder;
    function Error(const AMessage: string): IApolloLogBuilder; overload;
    function Error(const AMessage: string; const AException: Exception): IApolloLogBuilder; overload;
    function Fatal(const AMessage: string): IApolloLogBuilder;
    function MinLevel(const ALevel: TApolloLogLevel): IApolloLogger;
    function LoggerName(const AName: string): IApolloLogger;
  end;

  TApolloLogBuilder = class(TInterfacedObject, IApolloLogBuilder)
  private
    FEntry: TApolloLogEntry;
    FDispatcher: TApolloDispatcher;
    FFields: TList<TPair<string, TApolloFieldValue>>;
  public
    constructor Create(const ADispatcher: TApolloDispatcher;
      const AEntry: TApolloLogEntry);
    destructor Destroy; override;
    function Field(const AKey, AValue: string): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Integer): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Double): IApolloLogBuilder; overload;
    function Field(const AKey: string; AValue: Boolean): IApolloLogBuilder; overload;
    function TraceId(const AId: string): IApolloLogBuilder;
    function SpanId(const AId: string): IApolloLogBuilder;
    procedure Emit;
  end;

  TApolloLogger = class(TInterfacedObject, IApolloLogger)
  private
    FDispatcher: TApolloDispatcher;
    FMinLevel: TApolloLogLevel;
    FLoggerName: string;
    function BuildEntry(const ALevel: TApolloLogLevel;
      const AMessage: string): IApolloLogBuilder;
  public
    constructor Create(const ADispatcher: TApolloDispatcher);
    class function New(const ADispatcher: TApolloDispatcher): IApolloLogger;
    function Trace(const AMessage: string): IApolloLogBuilder;
    function Debug(const AMessage: string): IApolloLogBuilder;
    function Info(const AMessage: string): IApolloLogBuilder;
    function Warn(const AMessage: string): IApolloLogBuilder;
    function Error(const AMessage: string): IApolloLogBuilder; overload;
    function Error(const AMessage: string; const AException: Exception): IApolloLogBuilder; overload;
    function Fatal(const AMessage: string): IApolloLogBuilder;
    function MinLevel(const ALevel: TApolloLogLevel): IApolloLogger;
    function LoggerName(const AName: string): IApolloLogger;
  end;

implementation

uses
  System.DateUtils;

{ TApolloLogBuilder }

constructor TApolloLogBuilder.Create(const ADispatcher: TApolloDispatcher;
  const AEntry: TApolloLogEntry);
begin
  inherited Create;
  FDispatcher := ADispatcher;
  FEntry := AEntry;
  FFields := TList<TPair<string, TApolloFieldValue>>.Create;
end;

destructor TApolloLogBuilder.Destroy;
begin
  FFields.Free;
  inherited;
end;

function TApolloLogBuilder.Field(const AKey, AValue: string): IApolloLogBuilder;
var
  LVal: TApolloFieldValue;
begin
  LVal.Kind     := fkString;
  LVal.AsString := AValue;
  FFields.Add(TPair<string, TApolloFieldValue>.Create(AKey, LVal));
  Result := Self;
end;

function TApolloLogBuilder.Field(const AKey: string; AValue: Integer): IApolloLogBuilder;
var
  LVal: TApolloFieldValue;
begin
  LVal.Kind    := fkInt64;
  LVal.AsInt64 := AValue;
  FFields.Add(TPair<string, TApolloFieldValue>.Create(AKey, LVal));
  Result := Self;
end;

function TApolloLogBuilder.Field(const AKey: string; AValue: Double): IApolloLogBuilder;
var
  LVal: TApolloFieldValue;
begin
  LVal.Kind     := fkDouble;
  LVal.AsDouble := AValue;
  FFields.Add(TPair<string, TApolloFieldValue>.Create(AKey, LVal));
  Result := Self;
end;

function TApolloLogBuilder.Field(const AKey: string; AValue: Boolean): IApolloLogBuilder;
var
  LVal: TApolloFieldValue;
begin
  LVal.Kind      := fkBoolean;
  LVal.AsBoolean := AValue;
  FFields.Add(TPair<string, TApolloFieldValue>.Create(AKey, LVal));
  Result := Self;
end;

function TApolloLogBuilder.TraceId(const AId: string): IApolloLogBuilder;
begin
  FEntry.TraceId := AId;
  Result := Self;
end;

function TApolloLogBuilder.SpanId(const AId: string): IApolloLogBuilder;
begin
  FEntry.SpanId := AId;
  Result := Self;
end;

procedure TApolloLogBuilder.Emit;
begin
  if not Assigned(FDispatcher) then
    Exit;
  FEntry.Fields := FFields.ToArray;
  FDispatcher.Enqueue(FEntry);
end;

{ TApolloLogger }

constructor TApolloLogger.Create(const ADispatcher: TApolloDispatcher);
begin
  inherited Create;
  FDispatcher := ADispatcher;
  FMinLevel := llTrace;
  FLoggerName := '';
end;

class function TApolloLogger.New(const ADispatcher: TApolloDispatcher): IApolloLogger;
begin
  Result := TApolloLogger.Create(ADispatcher);
end;

function TApolloLogger.BuildEntry(const ALevel: TApolloLogLevel;
  const AMessage: string): IApolloLogBuilder;
var
  LEntry: TApolloLogEntry;
begin
  if Ord(ALevel) < Ord(FMinLevel) then
  begin
    // Return a no-op builder that discards the entry
    LEntry.Timestamp := Now;
    LEntry.Level := ALevel;
    LEntry.Message := AMessage;
    LEntry.TraceId := '';
    LEntry.SpanId := '';
    LEntry.Logger := FLoggerName;
    Result := TApolloLogBuilder.Create(nil, LEntry);
    Exit;
  end;

  LEntry.Timestamp := Now;
  LEntry.Level := ALevel;
  LEntry.Message := AMessage;
  LEntry.TraceId := '';
  LEntry.SpanId := '';
  LEntry.Logger := FLoggerName;
  Result := TApolloLogBuilder.Create(FDispatcher, LEntry);
end;

function TApolloLogger.Trace(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llTrace, AMessage);
end;

function TApolloLogger.Debug(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llDebug, AMessage);
end;

function TApolloLogger.Info(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llInfo, AMessage);
end;

function TApolloLogger.Warn(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llWarn, AMessage);
end;

function TApolloLogger.Error(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llError, AMessage);
end;

function TApolloLogger.Error(const AMessage: string;
  const AException: Exception): IApolloLogBuilder;
begin
  Result := BuildEntry(llError, AMessage)
    .Field('error.type',    AException.ClassName)
    .Field('error.message', AException.Message);
end;

function TApolloLogger.Fatal(const AMessage: string): IApolloLogBuilder;
begin
  Result := BuildEntry(llFatal, AMessage);
end;

function TApolloLogger.MinLevel(const ALevel: TApolloLogLevel): IApolloLogger;
begin
  FMinLevel := ALevel;
  Result := Self;
end;

function TApolloLogger.LoggerName(const AName: string): IApolloLogger;
begin
  FLoggerName := AName;
  Result := Self;
end;

end.
