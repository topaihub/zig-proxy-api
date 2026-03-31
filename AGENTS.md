# AGENTS.md — zig-proxy-api

A Zig rewrite of CLIProxyAPI using zig-framework (vnext branch).

## Rules

Before writing any code, read the relevant rule documents:

- **Logging**: `docs/rules/logging.md` — RequestTrace, MethodTrace, StepTrace, structured logging. MANDATORY for all code changes.
- **Code Style**: `docs/rules/code-style.md` — naming, patterns, error handling, memory.
- **Architecture**: `docs/rules/architecture.md` — module dependencies, adding providers, adding routes.

## Quick Reminders

- Use framework Logger, never `std.debug.print`
- HTTP entry → RequestTrace, business method → MethodTrace, external call → StepTrace
- Structured fields via `LogField.string/int/boolean`, not string interpolation in messages
- vtable interfaces for polymorphism
- Every module has `root.zig` with `refAllDecls` test
- Run `scripts/check-logging.sh` before committing

## Project Structure

```
src/
├── main.zig          Entry point, all module wiring
├── server/           HTTP server, router, middleware, SSE, WebSocket, TLS
├── config/           JSON config, loader, watcher, diff, hot-reload, payload rules
├── auth/             Auth types, file store, API key, OAuth providers, callbacks, refresh, cloak
├── translator/       Format types, registry, pipeline, streaming, thinking, tools, multimodal
├── executor/         Executor interface, base, 12 provider executors
├── scheduler/        Credential selector, cooldown, model registry
├── store/            Git, PostgreSQL, Object storage backends
├── management/       Management API endpoints
├── logging/          Request logger
├── api/              API request handlers
├── tui/              Terminal UI, tabs, i18n, management client
├── wsrelay/          WebSocket relay
└── amp/              Amp CLI integration
```
