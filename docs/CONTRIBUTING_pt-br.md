# Contribuindo com o Apollo

Obrigado pelo interesse em contribuir com o Apollo.

## Escopo

Apollo é uma biblioteca de logging estruturado para Delphi. Contribuições são bem-vindas em:

- **Sinks** — novas implementações de `IApolloSink` (CloudWatch, Splunk, etc.)
- **Correções de bugs** — comportamento incorreto no dispatcher, formatação ou sinks existentes
- **Testes** — novas fixtures DUnitX para casos extremos
- **Documentação** — melhorias no playbook, correções de tradução

## Fluxo de Pull Request

1. Faça fork do repositório
2. Crie uma branch: `feat/minha-feature` ou `fix/descricao-do-problema`
3. Escreva ou atualize testes para sua mudança
4. Certifique-se de que todos os testes existentes passam
5. Abra um pull request com uma descrição clara

## Convenções de Código

- Classes: `T<Projeto>*` → `TApolloDispatcher`, `TApolloConsoleSink`
- Interfaces: `I<Projeto>*` → `IApolloLogger`, `IApolloSink`
- Exceções: `E<Projeto>*` → `EApolloSinkFailure`
- Units: `<Projeto>.<Modulo>.pas` → `Apollo.Sink.Seq.pas`, `Apollo.Dispatcher.pas`

## Mensagens de Commit

Use Conventional Commits em **pt-BR**:

```
feat(sink): adicionar sink CloudWatch Logs
fix(dispatcher): corrigir flush incompleto no shutdown
docs(playbook): atualizar exemplo de configuracao com Loki
```

Nunca incluir `Co-Authored-By:` de ferramentas de IA.

## Adicionando um Sink

1. Criar `src/Apollo.Sink.<Nome>.pas`
2. Implementar `IApolloSink.Write` e `IApolloSink.MinLevel`
3. Usar `System.Net.HttpClient` para transporte HTTP (sem Indy obrigatório)
4. Adicionar retry em 429/5xx com backoff exponencial
5. Adicionar um sample em `samples/`
6. Adicionar testes em `tests/`
7. Documentar em `docs/playbook/` e `docs/playbook_pt-br/`

## Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a Licença MIT.
