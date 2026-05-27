# 05 — Fluent API

## Global convenience functions

`Apollo.pas` exposes global functions that use the singleton dispatcher (`GApollo`):

```pascal
function ApolloTrace(const AMessage: string): IApolloLogBuilder;
function ApolloDebug(const AMessage: string): IApolloLogBuilder;
function ApolloInfo (const AMessage: string): IApolloLogBuilder;
function ApolloWarn (const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder;
function ApolloFatal(const AMessage: string): IApolloLogBuilder;
```

When `GApollo` is `nil` (no setup), these return a no-op builder. Calling `.Emit` does nothing.
This prevents access violations in library code that logs before a host application sets up Apollo.

## IApolloLogBuilder

The builder returned by the logging functions:

```pascal
type
  IApolloLogBuilder = interface
    function Field(const AKey: string; const AValue: string):  IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Integer): IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Int64):   IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Double):  IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Boolean): IApolloLogBuilder;
    function TraceId(const ATraceId: string): IApolloLogBuilder;
    function SpanId(const ASpanId: string):  IApolloLogBuilder;
    procedure Emit;
  end;
```

Every method except `Emit` returns `Self`, enabling chaining.

## Typed fields

```pascal
ApolloInfo('request')
  .Field('method', 'GET')       // string
  .Field('status', 200)         // Integer → stored as Int64
  .Field('latency', 14.5)       // Double  → uses invariant decimal separator
  .Field('cached', True)        // Boolean → 'true'/'false' in JSON
  .Emit;
```

## Trace correlation

```pascal
ApolloInfo('span started')
  .TraceId('4bf92f3577b34da6a3ce929d0e0e4736')
  .SpanId('00f067aa0ba902b7')
  .Emit;
```

`TraceId` and `SpanId` are only emitted in the output when non-empty.

## Exception logging

```pascal
try
  DoWork;
except
  on E: Exception do
    ApolloError('job failed', E)
      .Field('job_id', '42')
      .Emit;
end;
```

The exception overload automatically adds two fields: `error.type` (class name) and
`error.message` (exception message). These appear before any additional `.Field(...)` calls.

## Using IApolloLogger directly

For more control — per-component loggers, custom minimum level, context fields — use
`TApolloLogger.New(LDispatcher)`:

```pascal
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(LDispatcher);
  LLog.MinLevel(llWarn);

  LLog.Info('this is filtered').Emit;   // no-op — below MinLevel
  LLog.Warn('this goes through').Emit;
end;
```

---

**Previous**: [04 — Sinks](../04-sinks/README.md) | **Next**: [06 — Async Dispatcher](../06-async-dispatcher/README.md)
