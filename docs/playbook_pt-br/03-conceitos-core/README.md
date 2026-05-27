# 03 — Conceitos Core

## TApolloLogLevel

```pascal
type
  TApolloLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);
```

Os níveis são ordenados: `llTrace < llDebug < llInfo < llWarn < llError < llFatal`.
Cada sink tem um `MinLevel`. O dispatcher só envia uma entrada para um sink se
`entry.Level >= sink.MinLevel`.

Use `LevelToString(ALevel): string` para obter o nome canônico em maiúsculas (`'TRACE'`, `'INFO'`, etc.).

## TApolloLogEntry

O record central que percorre o pipeline:

```pascal
type
  TApolloLogEntry = record
    Level:     TApolloLogLevel;
    Message:   string;
    Timestamp: TDateTime;
    Logger:    string;                          // opcional — nome do logger
    TraceId:   string;                          // opcional — ID de trace distribuído
    SpanId:    string;                          // opcional — ID de span
    Fields:    TArray<TPair<string, TApolloFieldValue>>;
  end;
```

Entradas são value types (records). São criadas pelo builder e empurradas para a fila como
cópia — sem alocação de heap por entrada, exceto pelo array dinâmico de campos.

## TApolloFieldValue

Uma union discriminada para valores de campos tipados:

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

Os sinks usam `Kind` para serializar corretamente: inteiros sem aspas, booleanos como `true`/`false`,
doubles com separador decimal invariante. Use `FieldValueToJSON(AValue)` de `Apollo.Entry`
para obter um `TJSONValue` correspondente.

## IApolloSink

O contrato que todo sink deve implementar:

```pascal
type
  IApolloSink = interface
    ['{...}']
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

`Write` é chamado uma vez por ciclo de flush com todas as entradas filtradas para `>= MinLevel`.
Executa em uma thread `TTask` — não na thread da aplicação. As implementações devem ser
thread-safe para seu próprio estado.

## EntryToJSON

`Apollo.Entry` expõe `EntryToJSON(AEntry): string` que produz um objeto JSON compacto
adequado para sinks NDJSON (File, corpo do Elasticsearch bulk). O objeto inclui `@timestamp`
no formato ISO-8601, `level`, `message`, `logger`/`traceId`/`spanId` opcionais, e um objeto
`fields` somente quando há pelo menos um campo.

---

**Anterior**: [02 — Instalação](../02-instalacao/README.md) | **Próximo**: [04 — Sinks](../04-sinks/README.md)
