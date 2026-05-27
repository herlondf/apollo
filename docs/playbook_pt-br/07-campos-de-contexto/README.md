# 07 — Campos de Contexto

## O que são campos de contexto?

Campos de contexto são pares chave-valor anexados a uma instância de `TApolloLogger` que são
automaticamente adicionados a toda entrada de log emitida por aquele logger. Eles evitam a
repetição das mesmas chamadas `.Field(...)` em cada entrada.

## Definindo campos de contexto

`IApolloLogger` expõe quatro sobrecargas de `WithContext`, uma para cada tipo suportado:

```pascal
function WithContext(const AKey: string; const AValue: string):  IApolloLogger;
function WithContext(const AKey: string; const AValue: Integer): IApolloLogger;
function WithContext(const AKey: string; const AValue: Double):  IApolloLogger;
function WithContext(const AKey: string; const AValue: Boolean): IApolloLogger;
```

Cada uma retorna `Self`, portanto as chamadas encadeiam:

```pascal
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(LDispatcher)
    .WithContext('service', 'order-processor')
    .WithContext('version', 3)
    .WithContext('region', 'us-east-1');
```

## Ordem dos campos

Os campos de contexto são prefixados ao array de campos da entrada, antes de qualquer chamada
`.Field(...)` no builder. Portanto os campos de contexto aparecem primeiro em toda saída:

```
service=order-processor  version=3  region=us-east-1  job_id=42
```

## Loggers com escopo por requisição

Os campos de contexto são parte da instância do logger, não da entrada. Para anexar contexto
por requisição sem poluir outras requisições, crie um novo logger por requisição (ou por worker):

```pascal
function ProcessarRequisicao(const AReq: TRequest): TResponse;
var
  LLog: IApolloLogger;
begin
  LLog := TApolloLogger.New(FDispatcher)
    .WithContext('request_id', AReq.Id)
    .WithContext('user_id', AReq.UserId);

  LLog.Info('requisicao recebida').Field('method', AReq.Method).Emit;
  // ...
  LLog.Info('requisicao concluida').Field('status', 200).Emit;
end;
```

Ambas as entradas carregam `request_id` e `user_id` sem repetição manual.

## Sobrescrevendo campos de contexto

Se uma chamada `.Field(...)` no builder usar a mesma chave que um campo de contexto, ambos
aparecem na entrada. O campo de contexto vem primeiro; o campo do builder vem depois. Os sinks
veem ambos os valores. Se a deduplicação downstream for importante, use chaves distintas.

---

**Anterior**: [06 — Dispatcher Assíncrono](../06-dispatcher-async/README.md) | **Próximo**: [08 — Sinks Customizados](../08-sinks-customizados/README.md)
