# 09 — Production

## Level tuning

Set each sink's minimum level to match its cost:

| Sink | Recommended MinLevel |
|------|----------------------|
| Console | `llDebug` (dev) / `llWarn` (prod) |
| File | `llInfo` |
| Seq | `llInfo` |
| Loki | `llWarn` |
| Elasticsearch | `llInfo` |
| Datadog | `llWarn` or `llError` (cost per event) |
| OTLP | `llInfo` |

The dispatcher only sends entries to sinks that need them. Low-cost sinks can log more;
high-cost sinks should log less.

## Queue capacity

The default queue capacity is 10,000 entries. If your application emits bursts larger than
this, entries are dropped silently. Signs of queue saturation: log gaps during spikes.

Mitigation: raise the minimum level during spikes, or reduce log volume at the call site.

## Structured fields over string concatenation

Prefer structured fields over embedding values in the message string:

```pascal
// Bad — unsearchable
ApolloInfo('user ' + IntToStr(UserId) + ' logged in from ' + IP).Emit;

// Good — filterable by user_id and ip
ApolloInfo('user logged in')
  .Field('user_id', UserId)
  .Field('ip', IP)
  .Emit;
```

## Shutdown

Always call `Stop` before `Free`:

```pascal
Application.OnTerminate :=
  procedure
  begin
    LDispatcher.Stop;
    LDispatcher.Free;
  end;
```

`Stop` drains the queue. Entries emitted before `Stop` are guaranteed to be delivered.
Skipping `Stop` may lose the last few seconds of log entries.

## Monitoring sink errors

Sink errors go to stderr. In production, redirect stderr to a file or alerting pipeline:

```bash
myapp.exe 2>> apollo-errors.log
```

Or, in a service wrapper, capture stderr separately from stdout.

## Thread safety summary

| Operation | Thread-safe? |
|-----------|-------------|
| `ApolloInfo(...).Emit` | Yes — multiple threads |
| `AddSink(...)` | No — only before `Start` |
| `TApolloConsoleSink.Write` | Yes — `TMonitor` protected |
| HTTP sinks `.Write` | Yes — fresh `THTTPClient` per call |
| `TApolloFileSink.Write` | Yes — `TMonitor` protected |

## Memory

Entries are `TApolloLogEntry` records (value types). The only heap allocation per entry is the
`TArray<TPair<string, TApolloFieldValue>>` for fields. Empty-field entries (trace/debug
checkpoints) allocate no array at all.

String fields hold a reference to a Delphi `string`, which is copy-on-write — no extra copies
when the entry is pushed into the queue.

---

**Previous**: [08 — Custom Sinks](../08-custom-sinks/README.md) | [Back to Playbook Index](../README.md)
