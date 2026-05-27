# 01 — Visão Geral

Apollo é uma biblioteca de logging estruturado e assíncrono para Delphi 11+. Ela oferece uma
forma única e uniforme de emitir entradas de log com campos tipados, correlação de traces e
informações de nível — e distribui essas entradas para qualquer combinação de sinks sem bloquear
a thread chamadora.

## O problema que resolve

O logging tradicional em Delphi (WriteLn, OutputDebugString, TFileLogger) tem dois problemas fundamentais:

1. **Sem estrutura** — mensagens são strings. Buscar por `user_id=42` requer regex.
2. **I/O síncrono** — cada chamada `Log('...')` bloqueia enquanto escreve em disco ou rede.

Apollo resolve ambos. Cada entrada de log é um record tipado (`TApolloLogEntry`) com campos
fortemente tipados. A emissão é um push não-bloqueante na fila. Uma thread em background faz
o I/O real.

## O que você ganha

- **Builder fluente**: `.Field('status', 200).TraceId('abc').Emit` — legível, encadeável.
- **Campos tipados**: int, double, boolean e string — serializados corretamente em cada formato de sink.
- **7 sinks embutidos**: Console, File (NDJSON), Seq (CLEF), Loki, Elasticsearch, Datadog, OTLP.
- **Dispatcher assíncrono**: entradas nunca bloqueiam a thread da aplicação.
- **Campos de contexto**: campos pré-definidos por logger que se propagam para todas as entradas.
- **Sem dependências externas**: usa apenas `System.Net.HttpClient` da RTL do Delphi.

## Arquitetura de alto nível

```
Thread da app
  └─ ApolloInfo('msg').Field('k', v).Emit
       └─ TThreadedQueue.Push  ← não-bloqueante, O(1)

Thread do dispatcher em background (500 ms ou 100 entradas)
  └─ Desenfileira lote
       └─ TTask.Run → ConsoleSink.Write(lote)
       └─ TTask.Run → SeqSink.Write(lote)
       └─ TTask.Run → LokiSink.Write(lote)
```

O dispatcher executa um `TTask` por sink por ciclo de flush. Os sinks executam em paralelo.
Se um sink lançar uma exceção, ela é escrita no stderr e o processamento continua — a aplicação
nunca é interrompida.

## Nomeado em homenagem a Apollo

Apollo é o deus grego da luz e da verdade — *trazendo as coisas à luz*. Todos os projetos da
família olímpica emitem observabilidade via Apollo.

---

**Próximo**: [02 — Instalação](../02-instalacao/README.md)
