# 04 — Sinks

Apollo ships with 7 built-in sinks. Each sink is a separate unit — add only what you use.

## Console (`Apollo.Sink.Console`)

Writes ANSI-colored lines to stdout. Thread-safe.

```pascal
TApolloConsoleSink.New(AMinLevel: TApolloLogLevel = llDebug): IApolloSink
```

Output format: `[YYYY-MM-DD HH:MM:SS] LEVEL  message  key=value ...`

## File (`Apollo.Sink.File`)

Writes NDJSON (newline-delimited JSON) with size-based rotation.

```pascal
TApolloFileSink.New(
  APath:       string;
  AMinLevel:   TApolloLogLevel = llInfo;
  AMaxSizeMB:  Integer = 100;
  AMaxBackups: Integer = 5
): IApolloSink
```

Rotation renames the current file to `.1`, shifts `.1→.2` … `.N-1→.N`, deletes `.N` if present.

## Seq (`Apollo.Sink.Seq`)

Sends CLEF (Compact Log Event Format) to a Seq server via HTTP POST to `/api/events/raw`.

```pascal
TApolloSeqSink.New(
  ABaseURL:  string;
  AApiKey:   string = '';
  AMinLevel: TApolloLogLevel = llInfo
): IApolloSink
```

## Loki (`Apollo.Sink.Loki`)

Sends to Grafana Loki's push API (`/loki/api/v1/push`). Returns `IApolloLokiSink` for fluent
configuration.

```pascal
TApolloLokiSink.New(ABaseURL: string; AMinLevel: TApolloLogLevel = llInfo): IApolloLokiSink

// Fluent methods:
.WithLabel(AKey, AValue: string): IApolloLokiSink   // add stream label
.BasicAuth(AUser, APassword: string): IApolloLokiSink
```

Entries are grouped into Loki streams by `level|logger`. Custom labels are added to every stream.

## Elasticsearch (`Apollo.Sink.Elasticsearch`)

Sends via the Bulk API (`/_bulk`). Index name rotates daily: `<prefix>-YYYY.MM.DD`.

```pascal
TApolloElasticsearchSink.New(
  ABaseURL:     string;
  AIndexPrefix: string = 'logs';
  AMinLevel:    TApolloLogLevel = llInfo
): IApolloElasticsearchSink

// Fluent methods:
.BasicAuth(AUser, APassword: string): IApolloElasticsearchSink
.ApiKey(AKey: string): IApolloElasticsearchSink     // sends ApiKey <key>
```

## Datadog (`Apollo.Sink.Datadog`)

Sends to Datadog Logs API v2. The DD-API-KEY header is set automatically.

```pascal
TApolloDatadogSink.New(AApiKey: string; AMinLevel: TApolloLogLevel = llInfo): IApolloDatadogSink

// Fluent methods:
.Service(AService: string): IApolloDatadogSink      // default: 'app'
.Site(ASite: string): IApolloDatadogSink            // 'datadoghq.com' | 'datadoghq.eu'
.Tag(ATags: string): IApolloDatadogSink             // e.g. 'env:prod,team:core'
```

Log level maps to Datadog status: `llTrace→trace`, `llFatal→critical`.

## OTLP (`Apollo.Sink.OTLP`)

Sends OpenTelemetry log records via OTLP/HTTP JSON to `/v1/logs`. Conforms to the
[OpenTelemetry Log Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/).

```pascal
TApolloOTLPSink.New(ACollectorURL: string; AMinLevel: TApolloLogLevel = llInfo): IApolloOTLPSink

// Fluent methods:
.ResourceAttribute(AKey, AValue: string): IApolloOTLPSink
.BearerToken(AToken: string): IApolloOTLPSink
.Authorization(AHeaderValue: string): IApolloOTLPSink  // custom header value
```

Severity numbers follow the OTLP spec: Trace=1, Debug=5, Info=9, Warn=13, Error=17, Fatal=21.
Field types map to OTLP attribute types: `intValue` (number), `doubleValue` (number),
`boolValue` (boolean), `stringValue` (string).

## Error handling in HTTP sinks

All HTTP sinks wrap `SendBatch` in a typed `except` block. On failure, the error is written
to `ErrOutput` (stderr) and the sink continues. The application is never disrupted.

```
[Apollo][LokiSink] ENetHTTPClientException: connection refused
```

---

**Previous**: [03 — Core Concepts](../03-core-concepts/README.md) | **Next**: [05 — Fluent API](../05-fluent-api/README.md)
