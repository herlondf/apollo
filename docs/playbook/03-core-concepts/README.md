# 03 — Core Concepts

## TApolloLogLevel

```pascal
type
  TApolloLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);
```

Levels are ordered: `llTrace < llDebug < llInfo < llWarn < llError < llFatal`.
Each sink has a `MinLevel`. The dispatcher only sends an entry to a sink if
`entry.Level >= sink.MinLevel`.

Use `LevelToString(ALevel): string` to get the canonical uppercase name (`'TRACE'`, `'INFO'`, etc.).

## TApolloLogEntry

The central record that travels through the pipeline:

```pascal
type
  TApolloLogEntry = record
    Level:     TApolloLogLevel;
    Message:   string;
    Timestamp: TDateTime;
    Logger:    string;                          // optional — logger name
    TraceId:   string;                          // optional — distributed trace ID
    SpanId:    string;                          // optional — span ID
    Fields:    TArray<TPair<string, TApolloFieldValue>>;
  end;
```

Entries are value types (records). They are created by the builder and pushed into the queue
as a copy — no heap allocation per entry beyond the dynamic array of fields.

## TApolloFieldValue

A discriminated union for typed field values:

```pascal
type
  TApolloFieldKind = (fkString, fkInt64, fkDouble, fkBoolean);

  TApolloFieldValue = record
    Kind:      TApolloFieldKind;
    AsString:  string;
    AsInt64:   Int64;
    AsDouble:  Double;
    AsBoolean: Boolean;
  end;
```

Sinks use `Kind` to serialize correctly: integers without quotes, booleans as `true`/`false`,
doubles with invariant decimal separator. Use `FieldValueToJSON(AValue)` from `Apollo.Entry`
to get a `TJSONValue` for the value.

## IApolloSink

The contract every sink must implement:

```pascal
type
  IApolloSink = interface
    ['{...}']
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

`Write` is called once per flush cycle with all entries filtered to `>= MinLevel`. It runs on
a `TTask` thread — not the application thread. Implementations must be thread-safe for their
own state.

## EntryToJSON

`Apollo.Entry` exposes `EntryToJSON(AEntry): string` which produces a compact JSON object
suitable for NDJSON sinks (File, Elasticsearch bulk body). The object includes `@timestamp`
in ISO-8601 format, `level`, `message`, optional `logger`/`traceId`/`spanId`, and a `fields`
object only when there is at least one field.

---

**Previous**: [02 — Installation](../02-installation/README.md) | **Next**: [04 — Sinks](../04-sinks/README.md)
