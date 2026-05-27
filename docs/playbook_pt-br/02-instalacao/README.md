# 02 — Instalação

## Requisitos

- **Delphi 11 Alexandria** ou superior (usa `TFormatSettings.Invariant`, `TTask`, `TThreadedQueue`)
- Nenhum pacote externo obrigatório

## Clonar o repositório

```bash
git clone https://github.com/herlondf/apollo.git
```

## Adicionar ao search path

No `.dproj` do seu projeto, adicione o diretório `src` ao `DCC_UnitSearchPath`:

```
apollo\src
```

Ou use um caminho relativo nas opções do projeto na IDE:

```
..\apollo\src
```

## Adicionar units ao .dpr

Liste apenas as units que você usa. O Delphi resolve as dependências automaticamente
pelo search path.

```pascal
uses
  Apollo              in 'caminho\para\apollo\src\Apollo.pas',
  Apollo.Entry        in 'caminho\para\apollo\src\Apollo.Entry.pas',
  Apollo.Logger       in 'caminho\para\apollo\src\Apollo.Logger.pas',
  Apollo.Dispatcher   in 'caminho\para\apollo\src\Apollo.Dispatcher.pas',
  Apollo.Sink.Interfaces in 'caminho\para\apollo\src\Apollo.Sink.Interfaces.pas',
  Apollo.Sink.Console in 'caminho\para\apollo\src\Apollo.Sink.Console.pas';
```

## Programa mínimo funcional

```pascal
program MeuApp;

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

    ApolloInfo('olá').Field('de', 'apollo').Emit;

    LDispatcher.Stop;
  finally
    LDispatcher.Free;
  end;
end.
```

Saída esperada:

```
[2024-01-01 12:00:00] INFO   olá  de=apollo
```

---

**Anterior**: [01 — Visão Geral](../01-visao-geral/README.md) | **Próximo**: [03 — Conceitos Core](../03-conceitos-core/README.md)
