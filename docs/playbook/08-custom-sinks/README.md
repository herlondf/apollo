# 08 — Custom Sinks

## The interface

Implementing a custom sink requires only two methods:

```pascal
type
  IApolloSink = interface
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

## Minimal example: in-memory sink for testing

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

function TCaptureSink.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TCaptureSink.Last: TApolloLogEntry;
begin
  Result := FEntries.Last;
end;
```

## Full HTTP sink example

For an HTTP sink, follow the same pattern as the built-in sinks:

1. Accept configuration in the constructor.
2. Expose fluent configuration methods on a typed interface.
3. `Write` builds the payload and calls `SendBatch`.
4. `SendBatch` creates a fresh `THTTPClient`, POSTs, and frees it.
5. Wrap `SendBatch` with `on E: Exception do WriteLn(ErrOutput, ...)`.

```pascal
type
  IMyWebhookSink = interface(IApolloSink)
    ['{...}']
    function BearerToken(const AToken: string): IMyWebhookSink;
  end;

  TMyWebhookSink = class(TInterfacedObject, IApolloSink, IMyWebhookSink)
  private
    FURL: string;
    FToken: string;
    FMinLevel: TApolloLogLevel;
    procedure SendBatch(const ABody: string);
  public
    class function New(const AURL: string;
      const AMinLevel: TApolloLogLevel = llInfo): IMyWebhookSink;
    constructor Create(const AURL: string; const AMinLevel: TApolloLogLevel);
    function BearerToken(const AToken: string): IMyWebhookSink;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;
```

## Guidelines

- Never store a reference to the dispatcher or logger inside a sink — only to configuration.
- `Write` is called from a `TTask` thread. If your sink has shared mutable state, protect it
  with `TMonitor` or `TCriticalSection`.
- Batch all entries from a single `Write` call into one HTTP request. Avoid one request per entry.
- For HTTP sinks, always use `on E: Exception do WriteLn(ErrOutput, ...)` — never swallow silently
  and never re-raise (it would crash the dispatcher's task thread).

---

**Previous**: [07 — Context Fields](../07-context-fields/README.md) | **Next**: [09 — Production](../09-production/README.md)
