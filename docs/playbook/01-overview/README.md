# 01 — Overview

Apollo is a structured, asynchronous logging library for Delphi 11+. It gives your application
a single, uniform way to emit log entries that carry typed fields, trace correlation, and level
information — then fan them out to any combination of sinks without blocking the calling thread.

## The problem it solves

Traditional Delphi logging (WriteLn, OutputDebugString, TFileLogger) has two fundamental problems:

1. **No structure** — messages are strings. Searching by `user_id=42` requires regex.
2. **Synchronous I/O** — every `Log('...')` call blocks while writing to disk or network.

Apollo addresses both. Every log entry is a typed record (`TApolloLogEntry`) with strongly-typed
fields. Emitting is a non-blocking queue push. A background thread does the actual I/O.

## What you get

- **Fluent builder**: `.Field('status', 200).TraceId('abc').Emit` — readable, chainable.
- **Typed fields**: int, double, boolean, and string — serialized correctly in each sink format.
- **7 built-in sinks**: Console, File (NDJSON), Seq (CLEF), Loki, Elasticsearch, Datadog, OTLP.
- **Async dispatcher**: entries never block the application thread.
- **Context fields**: per-logger pre-set fields that propagate to every entry.
- **No dependencies**: uses only `System.Net.HttpClient` from the Delphi RTL.

## High-level architecture

```
App thread
  └─ ApolloInfo('msg').Field('k', v).Emit
       └─ TThreadedQueue.Push  ← non-blocking, O(1)

Background dispatcher thread (500 ms or 100 entries)
  └─ Dequeue batch
       └─ TTask.Run → ConsoleSink.Write(batch)
       └─ TTask.Run → SeqSink.Write(batch)
       └─ TTask.Run → LokiSink.Write(batch)
```

The dispatcher runs one `TTask` per sink per flush cycle. Sinks execute in parallel. If a sink
raises an exception, it writes to stderr and continues — the application is never disrupted.

## Named after Apollo

Apollo is the Greek god of light and truth — *bringing things to light*. Every project in the
Olympian family emits observability through Apollo.

---

**Next**: [02 — Installation](../02-installation/README.md)
