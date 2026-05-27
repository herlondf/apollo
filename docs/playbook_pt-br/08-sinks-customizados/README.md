# 08 — Sinks Customizados

## A interface

Implementar um sink customizado requer apenas dois métodos:

```pascal
type
  IApolloSink = interface
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

## Exemplo mínimo: sink em memória para testes

```pascal
type
  TCaptureSink = class(TInterfacedObject, IApolloSink)
  private
    FEntries: TList<TApolloLogEntry>;
    FMinLevel: TApolloLogLevel;
  public
    constructor Create(const AMinLevel: TApolloLogLevel = llTrace);
    destructor Destroy; override;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
    function Count: Integer;
    function Last: TApolloLogEntry;
  end;

constructor TCaptureSink.Create(const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FEntries := TList<TApolloLogEntry>.Create;
  FMinLevel := AMinLevel;
end;

destructor TCaptureSink.Destroy;
begin
  FEntries.Free;
  inherited;
end;

procedure TCaptureSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LEntry: TApolloLogEntry;
begin
  for LEntry in AEntries do
    FEntries.Add(LEntry);
end;

function TCaptureSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;
```

## Exemplo de sink HTTP completo

Para um sink HTTP, siga o mesmo padrão dos sinks embutidos:

1. Aceite configuração no construtor.
2. Exponha métodos de configuração fluentes em uma interface tipada.
3. `Write` constrói o payload e chama `SendBatch`.
4. `SendBatch` cria um `THTTPClient` novo, faz o POST e libera.
5. Envolva `SendBatch` com `on E: Exception do WriteLn(ErrOutput, ...)`.

```pascal
type
  IMeuWebhookSink = interface(IApolloSink)
    ['{...}']
    function BearerToken(const AToken: string): IMeuWebhookSink;
  end;

  TMeuWebhookSink = class(TInterfacedObject, IApolloSink, IMeuWebhookSink)
  private
    FURL: string;
    FToken: string;
    FMinLevel: TApolloLogLevel;
    procedure SendBatch(const ABody: string);
  public
    class function New(const AURL: string;
      const AMinLevel: TApolloLogLevel = llInfo): IMeuWebhookSink;
    constructor Create(const AURL: string; const AMinLevel: TApolloLogLevel);
    function BearerToken(const AToken: string): IMeuWebhookSink;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

## Diretrizes

- Nunca armazene uma referência ao dispatcher ou logger dentro de um sink — apenas configuração.
- `Write` é chamado de uma thread `TTask`. Se o seu sink tiver estado mutável compartilhado,
  proteja-o com `TMonitor` ou `TCriticalSection`.
- Agrupe todas as entradas de uma única chamada `Write` em uma única requisição HTTP. Evite
  uma requisição por entrada.
- Para sinks HTTP, sempre use `on E: Exception do WriteLn(ErrOutput, ...)` — nunca engula
  silenciosamente e nunca relance (isso travaria a thread de task do dispatcher).

---

**Anterior**: [07 — Campos de Contexto](../07-campos-de-contexto/README.md) | **Próximo**: [09 — Produção](../09-producao/README.md)
