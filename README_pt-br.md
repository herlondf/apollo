# Apollo

<p align="center">
  <img src="docs/logo.png" alt="Apollo" width="280">
</p>

<p align="center">
  Logging estruturado para Delphi — API fluente, dispatcher assíncrono, sinks plugáveis, OpenTelemetry.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"></a>
  <a href="https://www.embarcadero.com/products/delphi"><img src="https://img.shields.io/badge/Delphi-11%2B-red?style=flat-square" alt="Delphi 11+"></a>
  <a href="#sinks"><img src="https://img.shields.io/badge/sinks-7%20built--in-orange?style=flat-square" alt="7 Sinks"></a>
</p>

---

Apollo traz logging estruturado e assíncrono ao Delphi. Nomeado em homenagem ao deus da luz e da
verdade — *trazendo as coisas à luz*. Todos os projetos da família olímpica emitem logs via Apollo.

## Início Rápido

```pascal
uses Apollo, Apollo.Sink.Console, Apollo.Dispatcher;

var
  LDispatcher: TApolloDispatcher;
begin
  LDispatcher := TApolloDispatcher.New;
  LDispatcher.AddSink(TApolloConsoleSink.New(llInfo));
  ApolloSetup(LDispatcher);
  LDispatcher.Start;

  ApolloInfo('servidor iniciado').Field('porta', 9000).Emit;
  ApolloWarn('memoria alta').Field('mb', 512).Emit;
  ApolloError('job falhou', E).Field('job_id', '123').Emit;
end;
```

## API Fluente

```pascal
ApolloInfo('requisicao processada')
  .Field('method', 'GET')
  .Field('path', '/users')
  .Field('status', 200)
  .Field('ms', 14)
  .TraceId('abc123')
  .SpanId('def456')
  .Emit;
```

## Níveis de Log

```pascal
ApolloTrace('detalhe verboso').Emit;
ApolloDebug('estado interno').Emit;
ApolloInfo('evento normal').Emit;
ApolloWarn('algo inesperado').Emit;
ApolloError('algo falhou').Emit;
ApolloFatal('irrecuperavel').Emit;
```

## Instalação

```bash
git clone https://github.com/herlondf/apollo.git
```

Adicione ao search path do projeto:

```
apollo\src
```

Sem dependências externas — usa apenas `System.Net.HttpClient` (RTL) para sinks HTTP.

## Requisitos

- **Delphi 11 Alexandria** ou superior
- Nenhuma dependência externa obrigatória

## Sinks

| Sink | Unit | Transporte |
|------|------|-----------|
| `TApolloConsoleSink` | `Apollo.Sink.Console` | Stdout com cores ANSI |
| `TApolloFileSink` | `Apollo.Sink.File` | Arquivo NDJSON com rotação por tamanho |
| `TApolloSeqSink` | `Apollo.Sink.Seq` | Seq — formato CLEF via HTTP |
| `TApolloLokiSink` | `Apollo.Sink.Loki` | Grafana Loki push API |
| `TApolloElasticsearchSink` | `Apollo.Sink.Elasticsearch` | Elasticsearch Bulk API |
| `TApolloDatadogSink` | `Apollo.Sink.Datadog` | Datadog Logs API v2 |
| `TApolloOTLPSink` | `Apollo.Sink.OTLP` | OpenTelemetry OTLP/HTTP `/v1/logs` |

Implemente `IApolloSink` (2 métodos) para adicionar o seu próprio.

## Múltiplos Sinks

```pascal
LDispatcher.AddSink(TApolloConsoleSink.New(llDebug));
LDispatcher.AddSink(TApolloSeqSink.New('http://seq:5341', 'my-api-key', llInfo));
LDispatcher.AddSink(TApolloLokiSink.New('http://loki:3100', llWarn));
```

Cada sink tem seu próprio nível mínimo. Console mostra debug; Loki recebe apenas warnings e acima.

## Seq

```pascal
uses Apollo.Sink.Seq;

LDispatcher.AddSink(
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

Com autenticação:

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

Use API key ao invés de usuário/senha:

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
    .Service('my-api')               // opcional — padrão: 'app'
    .Site('datadoghq.eu')            // opcional — padrão: datadoghq.com
    .Tag('env:production,team:core') // opcional — tags Datadog
);
```

## OpenTelemetry (OTLP)

```pascal
uses Apollo.Sink.OTLP;

LDispatcher.AddSink(
  TApolloOTLPSink.New('http://otel-collector:4318', llInfo)
    .ResourceAttribute('service.name', 'my-api')
    .ResourceAttribute('deployment.environment', 'production')
    .BearerToken('my-token')         // opcional — maioria dos collectors exige auth
);
```

Use um cabeçalho Authorization customizado quando Bearer não for suficiente:

```pascal
LDispatcher.AddSink(
  TApolloOTLPSink.New('http://otel-collector:4318', llInfo)
    .ResourceAttribute('service.name', 'my-api')
    .Authorization('Basic dXNlcjpwYXNz')
);
```

## Campos de Contexto

Campos pré-definidos que se propagam para todas as entradas emitidas pelo logger:

```pascal
var
  LLogger: IApolloLogger;
begin
  LLogger := TApolloLogger.New(LDispatcher)
    .WithContext('service', 'order-processor')
    .WithContext('version', 3)
    .WithContext('region', 'us-east-1');

  LLogger.Info('job iniciado').Field('job_id', '42').Emit;
  // → message=job iniciado  service=order-processor  version=3  region=us-east-1  job_id=42

  LLogger.Error('job falhou', E).Emit;
  // → error.type + error.message + todos os campos de contexto
end;
```

## Arquitetura

Apollo usa o padrão **produtor-consumidor**. Threads da aplicação enfileiram entradas de log
instantaneamente (sem bloqueio). Um dispatcher em background drena a fila em lotes e distribui
para os sinks em paralelo.

```
Thread da app → TThreadedQueue (capacidade 10.000) → Dispatcher background
                                                           ↓
                               TTask.Run por sink (flush paralelo)
                               ConsoleSink | SeqSink | LokiSink | ...
```

- Zero latência no hot path — `Emit` é um push na fila
- Flush em lote a cada 500ms ou 100 entradas (o que ocorrer primeiro)
- `Stop` drena as entradas restantes antes de encerrar

## Estrutura do Projeto

```
src/
  Apollo.pas                        Entry-point umbrella + singleton global
  Apollo.Entry.pas                  TApolloLogEntry, TApolloLogLevel
  Apollo.Sink.Interfaces.pas        Interface IApolloSink
  Apollo.Dispatcher.pas             TApolloDispatcher (fila async + thread)
  Apollo.Logger.pas                 IApolloLogger, IApolloLogBuilder
  Apollo.Sink.Console.pas           Sink console (cores ANSI)
  Apollo.Sink.File.pas              Sink arquivo (NDJSON, rotação)
  Apollo.Sink.Seq.pas               Sink Seq (CLEF)
  Apollo.Sink.Loki.pas              Sink Loki (push API)
  Apollo.Sink.Elasticsearch.pas     Sink Elasticsearch (Bulk API)
  Apollo.Sink.Datadog.pas           Sink Datadog (Logs API v2)
  Apollo.Sink.OTLP.pas              Sink OpenTelemetry OTLP

samples/                            Exemplos executáveis
tests/                              Testes DUnitX
docs/
  playbook/                         Guia em inglês
  playbook_pt-br/                   Guia em português
```

## Inspiração

Apollo é inspirado em [Serilog](https://serilog.net/) (C#), [Zap](https://github.com/uber-go/zap) (Go),
[Winston](https://github.com/winstonjs/winston) (Node.js) e [Logrus](https://github.com/sirupsen/logrus) (Go).
Os mesmos conceitos — campos estruturados, sinks assíncronos, outputs plugáveis — trazidos nativamente ao Delphi.

## A Família Olímpica

> *Poseidon comanda os mares — transporte bruto, a força das ondas.*
> *Triton guarda as águas do pai — gerencia o que flui, retém o que não pode se perder.*
> *Pégaso voa pelos céus — nasceu do sangue de Medusa, pela espada que Hermes deu a Perseu.*
> *Hermes percorre todos os reinos — carrega mensagens entre deuses, mortais e monstros.*
> *Hefesto forja nas profundezas — invisível, incansável, transformando matéria bruta em obra acabada.*
> *Iris vai e volta — o cliente HTTP que chama o mundo.*
> *Apollo é o deus da luz e da verdade — traz tudo à luz.*

| Projeto | Mito | Papel |
|---------|------|-------|
| [**Poseidon**](https://github.com/herlondf/poseidon) | Deus dos mares | Camada de transporte assíncrono — IOCP/epoll, I/O bruto |
| [**Triton**](https://github.com/herlondf/triton) | Filho de Poseidon, guardião das profundezas | Pool de recursos genérico — conexões, clientes, SMTP |
| [**Pegasus**](https://github.com/herlondf/pegasus) | Nascido do sangue de Poseidon, cavalgado por heróis | Framework HTTP — roteamento, middleware, providers |
| [**Hermes**](https://github.com/herlondf/hermes) | Mensageiro dos deuses, guia entre os reinos | Cliente Redis — chave-valor rápido, pub/sub, mensageria |
| [**Hefesto**](https://github.com/herlondf/hefesto) | Ferreiro dos deuses, trabalha nas profundezas | Background jobs — filas, workers, retry, scheduling |
| [**Iris**](https://github.com/herlondf/iris) | Deusa do arco-íris, mensageira que vai e volta | Cliente HTTP — API fluente, retry, transportes plugáveis |
| **Apollo** (esta lib) | Deus da luz e da verdade, traz as coisas à luz | Logging estruturado — sinks assíncronos, OTLP, Seq, Loki, Datadog |

---

## Contribuindo

Veja [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) · [docs/CONTRIBUTING_pt-br.md](docs/CONTRIBUTING_pt-br.md)

## Licença

MIT — use livremente em projetos comerciais e open-source.

---

> 🇺🇸 Read this document in English: [README.md](./README.md)
