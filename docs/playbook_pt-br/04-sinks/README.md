# 04 — Sinks

O Apollo inclui 7 sinks embutidos. Cada sink é uma unit separada — adicione apenas o que usar.

## Console (`Apollo.Sink.Console`)

Escreve linhas coloridas com ANSI no stdout. Thread-safe.

```pascal
TApolloConsoleSink.New(AMinLevel: TApolloLogLevel = llDebug): IApolloSink
```

Formato de saída: `[AAAA-MM-DD HH:MM:SS] LEVEL  mensagem  chave=valor ...`

## File (`Apollo.Sink.File`)

Escreve NDJSON (JSON delimitado por nova linha) com rotação por tamanho.

```pascal
TApolloFileSink.New(
  APath:       string;
  AMinLevel:   TApolloLogLevel = llInfo;
  AMaxSizeMB:  Integer = 100;
  AMaxBackups: Integer = 5
): IApolloSink
```

A rotação renomeia o arquivo atual para `.1`, desloca `.1→.2` … `.N-1→.N`, e exclui `.N` se existir.

## Seq (`Apollo.Sink.Seq`)

Envia CLEF (Compact Log Event Format) para um servidor Seq via HTTP POST em `/api/events/raw`.

```pascal
TApolloSeqSink.New(
  ABaseURL:  string;
  AApiKey:   string = '';
  AMinLevel: TApolloLogLevel = llInfo
): IApolloSink
```

## Loki (`Apollo.Sink.Loki`)

Envia para a push API do Grafana Loki (`/loki/api/v1/push`). Retorna `IApolloLokiSink` para
configuração fluente.

```pascal
TApolloLokiSink.New(ABaseURL: string; AMinLevel: TApolloLogLevel = llInfo): IApolloLokiSink

// Métodos fluentes:
.WithLabel(AKey, AValue: string): IApolloLokiSink   // adiciona label ao stream
.BasicAuth(AUser, APassword: string): IApolloLokiSink
```

As entradas são agrupadas em streams Loki por `level|logger`. Labels customizados são
adicionados a todos os streams.

## Elasticsearch (`Apollo.Sink.Elasticsearch`)

Envia via Bulk API (`/_bulk`). O nome do índice rotaciona diariamente: `<prefixo>-AAAA.MM.DD`.

```pascal
TApolloElasticsearchSink.New(
  ABaseURL:     string;
  AIndexPrefix: string = 'logs';
  AMinLevel:    TApolloLogLevel = llInfo
): IApolloElasticsearchSink

// Métodos fluentes:
.BasicAuth(AUser, APassword: string): IApolloElasticsearchSink
.ApiKey(AKey: string): IApolloElasticsearchSink     // envia ApiKey <chave>
```

## Datadog (`Apollo.Sink.Datadog`)

Envia para a Datadog Logs API v2. O cabeçalho DD-API-KEY é definido automaticamente.

```pascal
TApolloDatadogSink.New(AApiKey: string; AMinLevel: TApolloLogLevel = llInfo): IApolloDatadogSink

// Métodos fluentes:
.Service(AService: string): IApolloDatadogSink      // padrão: 'app'
.Site(ASite: string): IApolloDatadogSink            // 'datadoghq.com' | 'datadoghq.eu'
.Tag(ATags: string): IApolloDatadogSink             // ex: 'env:prod,team:core'
```

O nível de log mapeia para o status do Datadog: `llTrace→trace`, `llFatal→critical`.

## OTLP (`Apollo.Sink.OTLP`)

Envia registros de log OpenTelemetry via OTLP/HTTP JSON para `/v1/logs`. Está em conformidade
com o [OpenTelemetry Log Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/).

```pascal
TApolloOTLPSink.New(ACollectorURL: string; AMinLevel: TApolloLogLevel = llInfo): IApolloOTLPSink

// Métodos fluentes:
.ResourceAttribute(AKey, AValue: string): IApolloOTLPSink
.BearerToken(AToken: string): IApolloOTLPSink
.Authorization(AHeaderValue: string): IApolloOTLPSink  // valor de cabeçalho customizado
```

Números de severidade seguem a spec OTLP: Trace=1, Debug=5, Info=9, Warn=13, Error=17, Fatal=21.
Tipos de campos mapeiam para tipos de atributo OTLP: `intValue` (número), `doubleValue` (número),
`boolValue` (booleano), `stringValue` (string).

## Tratamento de erros em sinks HTTP

Todos os sinks HTTP envolvem `SendBatch` em um bloco `except` tipado. Em caso de falha, o
erro é escrito em `ErrOutput` (stderr) e o sink continua. A aplicação nunca é interrompida.

```
[Apollo][LokiSink] ENetHTTPClientException: connection refused
```

---

**Anterior**: [03 — Conceitos Core](../03-conceitos-core/README.md) | **Próximo**: [05 — API Fluente](../05-api-fluente/README.md)
