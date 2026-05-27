# 07 — Context Fields

## What are context fields?

Context fields are key-value pairs attached to a `TApolloLogger` instance that are automatically
appended to every log entry emitted by that logger. They save you from repeating the same
`.Field(...)` calls on every entry.

## Setting context fields

`IApolloLogger` exposes four overloads of `WithContext`, one for each supported type:

```pascal
function WithContext(const AKey: string; const AValue: string):  IApolloLogger;
function WithContext(const AKey: string; const AValue: Integer): IApolloLogger;
function WithContext(const AKey: string; const AValue: Double):  IApolloLogger;
function WithContext(const AKey: string; const AValue: Boolean): IApolloLogger;
```

Each returns `Self`, so calls chain:

```pascal
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(LDispatcher)
    .WithContext('service', 'order-processor')
    .WithContext('version', 3)
    .WithContext('region', 'us-east-1');
```

## Field ordering

Context fields are prepended to the entry's field array, before any `.Field(...)` calls on
the builder. This means context fields come first in every output:

```
service=order-processor  version=3  region=us-east-1  job_id=42
```

## Scoped loggers per request

Context fields are part of the logger instance, not the entry. To attach per-request context
without polluting other requests, create a new logger per request (or per worker):

```pascal
function HandleRequest(const AReq: TRequest): TResponse;
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(FDispatcher)
    .WithContext('request_id', AReq.Id)
    .WithContext('user_id', AReq.UserId);

  LLog.Info('request received').Field('method', AReq.Method).Emit;
  // ...
  LLog.Info('request completed').Field('status', 200).Emit;
end;
```

Both entries carry `request_id` and `user_id` without manual repetition.

## Overriding context fields

If a builder `.Field(...)` call uses the same key as a context field, both appear in the entry.
The context field comes first; the builder field comes second. Sinks see both values. If
downstream deduplication matters, use distinct keys.

---

**Previous**: [06 — Async Dispatcher](../06-async-dispatcher/README.md) | **Next**: [08 — Custom Sinks](../08-custom-sinks/README.md)
