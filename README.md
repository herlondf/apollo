# Apollo

<p align="center">
  <img src="docs/logo.png" alt="Apollo" width="280">
</p>

<p align="center">
  Structured logging for Delphi — fluent API, async dispatcher, pluggable sinks, OpenTelemetry.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"></a>
  <a href="https://www.embarcadero.com/products/delphi"><img src="https://img.shields.io/badge/Delphi-11%2B-red?style=flat-square" alt="Delphi 11+"></a>
  <a href="#sinks"><img src="https://img.shields.io/badge/sinks-7%20built--in-orange?style=flat-square" alt="7 Sinks"></a>
</p>

---

Apollo brings structured, async logging to Delphi. Named after the god of light and truth —
*bringing things to light*. Every project in the Olympian family emits logs through Apollo.

## Quick Start

```pascal
uses Apollo, Apollo.Sink.Console, Apollo.Dispatcher;

var
  LDispatcher: TApolloDispatcher;
begin
  LDispatcher := TApolloDispatcher.New;
  LDispatcher.AddSink(TApolloConsoleSink.New(llInfo));
  ApolloSetup(LDispatcher);
  LDispatcher.Start;

  ApolloInfo('server started').Field('port', 9000).Emit;
  ApolloWarn('high memory').Field('mb', 512).Emit;
  ApolloError('job failed', E).Field('job_id', '123').Emit;
end;
```

## Fluent API

```pascal
ApolloInfo('request processed')
  .Field('method', 'GET')
  .Field('path', '/users')
  .Field('status', 200)
  .Field('ms', 14)
  .TraceId('abc123')
  .SpanId('def456')
  .Emit;
```

## Log Levels

```pascal
ApolloTrace('verbose detail').Emit;
ApolloDebug('internal state').Emit;
ApolloInfo('normal event').Emit;
ApolloWarn('something unexpected').Emit;
ApolloError('something failed').Emit;
ApolloFatal('unrecoverable').Emit;
```

## Installation

```bash
git clone https://github.com/herlondf/apollo.git
```

Add to Delphi project search path:

```
apollo\src
```

No external dependencies — uses only `System.Net.HttpClient` (RTL) for HTTP sinks.

## Requirements

- **Delphi 11 Alexandria** or later
- No mandatory external dependencies

## Sinks

| Sink | Unit | Transport |
|------|------|-----------|
| `TApolloConsoleSink` | `Apollo.Sink.Console` | Stdout with ANSI colors |
| `TApolloFileSink` | `Apollo.Sink.File` | NDJSON file with size rotation |
| `TApolloSeqSink` | `Apollo.Sink.Seq` | Seq — CLEF format over HTTP |
| `TApolloLokiSink` | `Apollo.Sink.Loki` | Grafana Loki push API |
| `TApolloElasticsearchSink` | `Apollo.Sink.Elasticsearch` | Elasticsearch Bulk API |
| `TApolloDatadogSink` | `Apollo.Sink.Datadog` | Datadog Logs API v2 |
| `TApolloOTLPSink` | `Apollo.Sink.OTLP` | OpenTelemetry OTLP/HTTP `/v1/logs` |

Implement `IApolloSink` (2 methods) to add your own.

## Multiple Sinks

```pascal
LDispatcher.AddSink(TApolloConsoleSink.New(llDebug));
LDispatcher.AddSink(TApolloSeqSink.New('http://seq:5341', 'my-api-key', llInfo));
LDispatcher.AddSink(TApolloLokiSink.New('http://loki:3100', llWarn));
```

Each sink has its own minimum level. Console shows debug; Loki only receives warnings and above.

## Seq

```pascal
uses Apollo.Sink.Seq;

Dispatcher.AddSink(
  TApolloSeqSink.New('http://seq:5341', 'my-api-key', llInfo)
);
```

## Loki

```pascal
uses Apollo.Sink.Loki;

LDispatcher.AddSink(
  TApolloLokiSink.New('http://loki:3100', llInfo)
    .WithLabel('app', 'my-api')
    .WithLabel('env', 'production')
);
```

With authentication:

```pascal
LDispatcher.AddSink(
  TApolloLokiSink.New('http://loki:3100', llInfo)
    .BasicAuth('admin', 'secret')
    .WithLabel('app', 'my-api')
);
```

## Elasticsearch

```pascal
uses Apollo.Sink.Elasticsearch;

LDispatcher.AddSink(
  TApolloElasticsearchSink.New('http://es:9200', 'logs-myapp', llInfo)
    .BasicAuth('elastic', 'password')
);
```

Use an API key instead of user/password:

```pascal
LDispatcher.AddSink(
  TApolloElasticsearchSink.New('http://es:9200', 'logs-myapp', llInfo)
    .ApiKey('my-encoded-api-key')
);
```

## Datadog

```pascal
uses Apollo.Sink.Datadog;

LDispatcher.AddSink(
  TApolloDatadogSink.New('my-dd-api-key', llInfo)
    .Service('my-api')               // optional — defaults to 'app'
    .Site('datadoghq.eu')            // optional — defaults to datadoghq.com
    .Tag('env:production,team:core') // optional — Datadog tags
);
```

## OpenTelemetry (OTLP)

```pascal
uses Apollo.Sink.OTLP;

LDispatcher.AddSink(
  TApolloOTLPSink.New('http://otel-collector:4318', llInfo)
    .ResourceAttribute('service.name', 'my-api')
    .ResourceAttribute('deployment.environment', 'production')
    .BearerToken('my-token')         // optional — most collectors require auth
);
```

Use a custom Authorization header when Bearer is not enough:

```pascal
LDispatcher.AddSink(
  TApolloOTLPSink.New('http://otel-collector:4318', llInfo)
    .ResourceAttribute('service.name', 'my-api')
    .Authorization('Basic dXNlcjpwYXNz')
);
```

## Context Fields

Pre-set fields that propagate to every log entry emitted by the logger:

```pascal
var
  LLogger: IApolloLogger;
begin
  LLogger := TApolloLogger.New(LDispatcher)
    .WithContext('service', 'order-processor')
    .WithContext('version', 3)
    .WithContext('region', 'us-east-1');

  LLogger.Info('job started').Field('job_id', '42').Emit;
  // → message=job started  service=order-processor  version=3  region=us-east-1  job_id=42

  LLogger.Error('job failed', E).Emit;
  // → error.type + error.message + all context fields
end;
```

## Architecture

Apollo uses a **producer-consumer** pattern. Application threads enqueue log entries
instantly (non-blocking). A background dispatcher drains the queue in batches and fans
out to sinks in parallel.

```
App thread → TThreadedQueue (capacity 10,000) → Background dispatcher
                                                      ↓
                              TTask.Run per sink (parallel flush)
                              ConsoleSink | SeqSink | LokiSink | ...
```

- Zero latency on the hot path — `Emit` is a queue push
- Batch flush every 500ms or 100 entries (whichever comes first)
- `Stop` drains remaining entries before exit

## Project Structure

```
src/
  Apollo.pas                        Entry-point umbrella + global singleton
  Apollo.Entry.pas                  TApolloLogEntry, TApolloLogLevel
  Apollo.Sink.Interfaces.pas        IApolloSink interface
  Apollo.Dispatcher.pas             TApolloDispatcher (async queue + thread)
  Apollo.Logger.pas                 IApolloLogger, IApolloLogBuilder
  Apollo.Sink.Console.pas           Console sink (ANSI colors)
  Apollo.Sink.File.pas              File sink (NDJSON, rotation)
  Apollo.Sink.Seq.pas               Seq sink (CLEF)
  Apollo.Sink.Loki.pas              Loki sink (push API)
  Apollo.Sink.Elasticsearch.pas     Elasticsearch sink (Bulk API)
  Apollo.Sink.Datadog.pas           Datadog sink (Logs API v2)
  Apollo.Sink.OTLP.pas              OpenTelemetry OTLP sink

samples/                            Runnable examples
tests/                              DUnitX tests
docs/
  playbook/                         English guide
  playbook_pt-br/                   Guia em português
```

## Inspiration

Apollo is inspired by [Serilog](https://serilog.net/) (C#), [Zap](https://github.com/uber-go/zap) (Go),
[Winston](https://github.com/winstonjs/winston) (Node.js), and [Logrus](https://github.com/sirupsen/logrus) (Go).
The same concepts — structured fields, async sinks, pluggable outputs — brought natively to Delphi.

## The Olympian Family

> *Poseidon commands the seas — raw transport, the force of the waves.*
> *Triton guards his father's waters — manages what flows, holds what must not be lost.*
> *Pegasus flies through the skies — born from Medusa's blood, by the sword Hermes gave to Perseus.*
> *Hermes runs between all realms — carries messages between gods, mortals and monsters.*
> *Hefesto forges in the depths — invisible, tireless, turning raw material into finished work.*
> *Iris goes and returns — the HTTP client that calls the world.*
> *Apollo is the god of light and truth — brings everything to light.*

| Project | Myth | Role |
|---------|------|------|
| [**Poseidon**](https://github.com/herlondf/poseidon) | God of the seas | Async transport layer — IOCP/epoll, raw I/O |
| [**Triton**](https://github.com/herlondf/triton) | Son of Poseidon, guardian of the depths | Generic resource pool — connections, clients, SMTP |
| [**Pegasus**](https://github.com/herlondf/pegasus) | Born from Poseidon's blood, ridden by heroes | HTTP framework — routing, middleware, providers |
| [**Hermes**](https://github.com/herlondf/hermes) | Messenger of the gods, guide between realms | Redis client — fast key-value, pub/sub, messaging |
| [**Hefesto**](https://github.com/herlondf/hefesto) | Forgemaster of the gods, works unseen | Background jobs — queues, workers, retry, scheduling |
| [**Iris**](https://github.com/herlondf/iris) | Goddess of the rainbow, messenger who returns | HTTP client — fluent API, retry, pluggable transports |
| **Apollo** (this lib) | God of light and truth, brings things to light | Structured logging — async sinks, OTLP, Seq, Loki, Datadog |

---

## License

MIT — use freely in commercial and open-source projects.

---

> 🇧🇷 Leia este documento em português: [README_pt-br.md](./README_pt-br.md)
