# 06 — Dispatcher Assíncrono

## TApolloDispatcher

O dispatcher é o coração do Apollo. Ele possui a fila e a thread em background.

```pascal
class function TApolloDispatcher.New: TApolloDispatcher;
procedure AddSink(const ASink: IApolloSink);
procedure Start;
procedure Stop;
```

`TApolloDispatcher` é uma classe concreta (não uma interface) porque a aplicação gerencia
seu ciclo de vida. Use `try/finally` e chame `Stop` antes de `Free`.

## Fila

Internamente, um `TThreadedQueue<TApolloLogEntry>` com capacidade de **10.000 entradas**.

- `Emit` empurra uma entrada na fila. Se a fila estiver cheia, a entrada é descartada silenciosamente.
- O push é O(1) e não-bloqueante — nunca espera por I/O.

## Ciclo de flush

A thread em background acorda a cada **500 ms** ou quando a fila atinge **100 entradas**,
o que ocorrer primeiro. Ela desenfileira todas as entradas disponíveis como um lote e então
inicia um `TTask.Run` por sink registrado. Os sinks executam concorrentemente.

```
Acorda a cada 500 ms (ou 100 entradas)
  └─ Desenfileira todas as entradas disponíveis
       └─ Filtra por sink: entry.Level >= sink.MinLevel
       └─ TTask.Run → sink1.Write(lote_filtrado)
       └─ TTask.Run → sink2.Write(lote_filtrado)
       └─ Aguarda todas as tasks
```

## Shutdown

```pascal
LDispatcher.Stop;
LDispatcher.Free;
```

`Stop` sinaliza a thread em background para encerrar e drena a fila restante antes de retornar.
Todas as entradas emitidas antes de `Stop` têm garantia de serem entregues.

Não chame `Free` no dispatcher sem chamar `Stop` primeiro — a thread em background pode
ainda estar escrevendo nos sinks.

## Segurança de threads

- `Emit` (push na fila) é thread-safe — múltiplas threads da aplicação podem chamar
  `ApolloInfo.Emit` concorrentemente.
- `AddSink` deve ser chamado antes de `Start`. Não adicione sinks após o dispatcher estar rodando.
- Os sinks são chamados de threads `TTask`. O sink Console usa `TMonitor` para sua própria
  thread-safety. Sinks HTTP criam um `THTTPClient` novo por chamada, o que é seguro.

---

**Anterior**: [05 — API Fluente](../05-api-fluente/README.md) | **Próximo**: [07 — Campos de Contexto](../07-campos-de-contexto/README.md)
