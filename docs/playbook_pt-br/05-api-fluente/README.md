# 05 — API Fluente

## Funções globais de conveniência

`Apollo.pas` expõe funções globais que usam o dispatcher singleton (`GApollo`):

```pascal
function ApolloTrace(const AMessage: string): IApolloLogBuilder;
function ApolloDebug(const AMessage: string): IApolloLogBuilder;
function ApolloInfo (const AMessage: string): IApolloLogBuilder;
function ApolloWarn (const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder;
function ApolloFatal(const AMessage: string): IApolloLogBuilder;
```

Quando `GApollo` é `nil` (sem setup), essas funções retornam um builder no-op. Chamar `.Emit`
não faz nada. Isso evita access violations em código de biblioteca que loga antes da aplicação
host configurar o Apollo.

## IApolloLogBuilder

O builder retornado pelas funções de logging:

```pascal
type
  IApolloLogBuilder = interface
    function Field(const AKey: string; const AValue: string):  IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Integer): IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Int64):   IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Double):  IApolloLogBuilder;
    function Field(const AKey: string; const AValue: Boolean): IApolloLogBuilder;
    function TraceId(const ATraceId: string): IApolloLogBuilder;
    function SpanId(const ASpanId: string):  IApolloLogBuilder;
    procedure Emit;
  end;
```

Todo método exceto `Emit` retorna `Self`, permitindo encadeamento.

## Campos tipados

```pascal
ApolloInfo('requisicao')
  .Field('method', 'GET')       // string
  .Field('status', 200)         // Integer → armazenado como Int64
  .Field('latencia', 14.5)      // Double  → usa separador decimal invariante
  .Field('cache', True)         // Boolean → 'true'/'false' no JSON
  .Emit;
```

## Correlação de traces

```pascal
ApolloInfo('span iniciado')
  .TraceId('4bf92f3577b34da6a3ce929d0e0e4736')
  .SpanId('00f067aa0ba902b7')
  .Emit;
```

`TraceId` e `SpanId` só são emitidos na saída quando não estão vazios.

## Logging de exceções

```pascal
try
  ExecutarTrabalho;
except
  on E: Exception do
    ApolloError('job falhou', E)
      .Field('job_id', '42')
      .Emit;
end;
```

A sobrecarga com exceção adiciona automaticamente dois campos: `error.type` (nome da classe)
e `error.message` (mensagem da exceção). Esses campos aparecem antes de qualquer chamada
adicional a `.Field(...)`.

## Usando IApolloLogger diretamente

Para mais controle — loggers por componente, nível mínimo customizado, campos de contexto —
use `TApolloLogger.New(LDispatcher)`:

```pascal
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(LDispatcher);
  LLog.MinLevel(llWarn);

  LLog.Info('isso é filtrado').Emit;   // no-op — abaixo do MinLevel
  LLog.Warn('isso passa').Emit;
end;
```

---

**Anterior**: [04 — Sinks](../04-sinks/README.md) | **Próximo**: [06 — Dispatcher Assíncrono](../06-dispatcher-async/README.md)
