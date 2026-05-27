# 02 — Installation

## Requirements

- **Delphi 11 Alexandria** or later (uses `TFormatSettings.Invariant`, `TTask`, `TThreadedQueue`)
- No mandatory external packages

## Clone the repository

```bash
git clone https://github.com/herlondf/apollo.git
```

## Add to search path

In your project's `.dproj`, add the `src` directory to `DCC_UnitSearchPath`:

```
apollo\src
```

Or use a relative path in IDE project options:

```
..\apollo\src
```

## Add units to your .dpr

List only the units you use. You do not need to list all of them — Delphi resolves dependencies
automatically via the search path.

```pascal
uses
  Apollo              in 'path\to\apollo\src\Apollo.pas',
  Apollo.Entry        in 'path\to\apollo\src\Apollo.Entry.pas',
  Apollo.Logger       in 'path\to\apollo\src\Apollo.Logger.pas',
  Apollo.Dispatcher   in 'path\to\apollo\src\Apollo.Dispatcher.pas',
  Apollo.Sink.Interfaces in 'path\to\apollo\src\Apollo.Sink.Interfaces.pas',
  Apollo.Sink.Console in 'path\to\apollo\src\Apollo.Sink.Console.pas';
```

## Minimal working program

```pascal
program MyApp;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Apollo,
  Apollo.Dispatcher,
  Apollo.Sink.Console;

var
  LDispatcher: TApolloDispatcher;
begin
  LDispatcher := TApolloDispatcher.New;
  try
    LDispatcher.AddSink(TApolloConsoleSink.New(llInfo));
    ApolloSetup(LDispatcher);
    LDispatcher.Start;

    ApolloInfo('hello').Field('from', 'apollo').Emit;

    LDispatcher.Stop;
  finally
    LDispatcher.Free;
  end;
end.
```

Expected output:

```
[2024-01-01 12:00:00] INFO   hello  from=apollo
```

---

**Previous**: [01 — Overview](../01-overview/README.md) | **Next**: [03 — Core Concepts](../03-core-concepts/README.md)
