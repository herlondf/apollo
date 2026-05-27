# Contributing to Apollo

Thank you for your interest in contributing to Apollo.

## Scope

Apollo is a structured logging library for Delphi. Contributions are welcome in:

- **Sinks** — new `IApolloSink` implementations (CloudWatch, Splunk, etc.)
- **Bug fixes** — incorrect behavior in dispatcher, formatting, or existing sinks
- **Tests** — new DUnitX fixtures for edge cases
- **Documentation** — playbook improvements, translation corrections

## Pull Request Flow

1. Fork the repository
2. Create a branch: `feat/my-feature` or `fix/issue-description`
3. Write or update tests for your change
4. Ensure all existing tests pass
5. Open a pull request with a clear description

## Code Conventions

- Classes: `T<Project>*` → `TApolloDispatcher`, `TApolloConsoleSink`
- Interfaces: `I<Project>*` → `IApolloLogger`, `IApolloSink`
- Exceptions: `E<Project>*` → `EApolloSinkFailure`
- Units: `<Project>.<Module>.pas` → `Apollo.Sink.Seq.pas`, `Apollo.Dispatcher.pas`

## Commit Messages

Use Conventional Commits in **pt-BR**:

```
feat(sink): adicionar sink CloudWatch Logs
fix(dispatcher): corrigir flush incompleto no shutdown
docs(playbook): atualizar exemplo de configuração com Loki
```

Never include `Co-Authored-By:` for AI tools.

## Adding a Sink

1. Create `src/Apollo.Sink.<Name>.pas`
2. Implement `IApolloSink.Write` and `IApolloSink.MinLevel`
3. Use `System.Net.HttpClient` for HTTP transport (no Indy required)
4. Add retry on 429/5xx using exponential backoff
5. Add a sample in `samples/`
6. Add tests in `tests/`
7. Document in `docs/playbook/` and `docs/playbook_pt-br/`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
