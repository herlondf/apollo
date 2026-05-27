# 06 — Async Dispatcher

## TApolloDispatcher

The dispatcher is the heart of Apollo. It owns the queue and the background thread.

```pascal
class function TApolloDispatcher.New: TApolloDispatcher;
procedure AddSink(const ASink: IApolloSink);
procedure Start;
procedure Stop;
```

`TApolloDispatcher` is a concrete class (not an interface) because the application owns its
lifetime. Use `try/finally` and call `Stop` before `Free`.

## Queue

Internally, a `TThreadedQueue<TApolloLogEntry>` with capacity **10,000 entries**.

- `Emit` pushes one entry onto the queue. If the queue is full, the entry is dropped silently.
- The push is O(1) and non-blocking — it never waits for I/O.

## Flush cycle

The background thread wakes up every **500 ms** or when the queue reaches **100 entries**,
whichever comes first. It dequeues all available entries as a batch, then starts one
`TTask.Run` per registered sink. Sinks run concurrently.

```
Wake up every 500 ms (or 100 entries)
  └─ Dequeue all available entries
       └─ Filter per sink: entry.Level >= sink.MinLevel
       └─ TTask.Run → sink1.Write(filtered_batch)
       └─ TTask.Run → sink2.Write(filtered_batch)
       └─ Wait for all tasks
```

## Shutdown

```pascal
LDispatcher.Stop;
LDispatcher.Free;
```

`Stop` signals the background thread to exit and drains the remaining queue before returning.
All entries emitted before `Stop` are guaranteed to be flushed.

Do not `Free` the dispatcher without calling `Stop` first — the background thread may still be
writing to sinks.

## Thread safety

- `Emit` (queue push) is thread-safe — multiple application threads can call `ApolloInfo.Emit`
  concurrently.
- `AddSink` must be called before `Start`. Do not add sinks after the dispatcher is running.
- Individual sinks are called from `TTask` threads. The Console sink uses `TMonitor` for its
  own thread-safety. HTTP sinks create a fresh `THTTPClient` per call, which is safe.

---

**Previous**: [05 — Fluent API](../05-fluent-api/README.md) | **Next**: [07 — Context Fields](../07-context-fields/README.md)
