# 09 — Produção

## Ajuste de nível

Defina o nível mínimo de cada sink conforme seu custo:

| Sink | MinLevel Recomendado |
|------|---------------------|
| Console | `llDebug` (dev) / `llWarn` (prod) |
| File | `llInfo` |
| Seq | `llInfo` |
| Loki | `llWarn` |
| Elasticsearch | `llInfo` |
| Datadog | `llWarn` ou `llError` (custo por evento) |
| OTLP | `llInfo` |

O dispatcher só envia entradas para os sinks que precisam delas. Sinks de baixo custo podem
registrar mais; sinks de alto custo devem registrar menos.

## Capacidade da fila

A capacidade padrão da fila é 10.000 entradas. Se sua aplicação emite rajadas maiores que
isso, as entradas são descartadas silenciosamente. Sinais de saturação da fila: lacunas no
log durante picos.

Mitigação: aumente o nível mínimo durante picos, ou reduza o volume de log no ponto de chamada.

## Campos estruturados em vez de concatenação de strings

Prefira campos estruturados a embutir valores na string da mensagem:

```pascal
// Ruim — impossível de filtrar
ApolloInfo('usuario ' + IntToStr(UserId) + ' logou de ' + IP).Emit;

// Bom — filtrável por user_id e ip
ApolloInfo('usuario logou')
  .Field('user_id', UserId)
  .Field('ip', IP)
  .Emit;
```

## Shutdown

Sempre chame `Stop` antes de `Free`:

```pascal
Application.OnTerminate :=
  procedure
  begin
    LDispatcher.Stop;
    LDispatcher.Free;
  end;
```

`Stop` drena a fila. As entradas emitidas antes de `Stop` têm garantia de serem entregues.
Pular `Stop` pode fazer você perder os últimos segundos de entradas de log.

## Monitorando erros de sink

Erros de sink vão para o stderr. Em produção, redirecione o stderr para um arquivo ou
pipeline de alertas:

```bash
meuapp.exe 2>> apollo-errors.log
```

Ou, num wrapper de serviço, capture o stderr separadamente do stdout.

## Resumo de segurança de threads

| Operação | Thread-safe? |
|----------|-------------|
| `ApolloInfo(...).Emit` | Sim — múltiplas threads |
| `AddSink(...)` | Não — apenas antes de `Start` |
| `TApolloConsoleSink.Write` | Sim — protegido por `TMonitor` |
| Sinks HTTP `.Write` | Sim — `THTTPClient` novo por chamada |
| `TApolloFileSink.Write` | Sim — protegido por `TMonitor` |

## Memória

Entradas são records `TApolloLogEntry` (value types). A única alocação de heap por entrada é
o `TArray<TPair<string, TApolloFieldValue>>` de campos. Entradas sem campos (checkpoints
trace/debug) não alocam nenhum array.

Campos string mantêm uma referência a uma `string` Delphi, que é copy-on-write — sem cópias
extras quando a entrada é empurrada na fila.

---

**Anterior**: [08 — Sinks Customizados](../08-sinks-customizados/README.md) | [Voltar ao Índice do Playbook](../README.md)
