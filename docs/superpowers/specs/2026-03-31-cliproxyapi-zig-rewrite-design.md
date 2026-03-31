# CLIProxyAPI Zig Rewrite — Master Design

## Overview

Rewrite [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) (Go) in Zig as an independent project (`zig-proxy-api`), using [zig-framework](https://github.com/topaihub/zig-framework.git) (`codex/framework-tooling-runtime-vnext` branch) as the application runtime foundation.

Goal: full feature parity with the original Go implementation.

## Project Structure

`zig-proxy-api` is a standalone Zig project that depends on `zig-framework` as a library. The framework provides kernel runtime (AppContext, Logger, EventBus, TaskRunner, ConfigStore), effects (HttpClient, FileSystem, ProcessRunner, Clock), tooling (ToolRegistry, ToolRunner, ScriptHost), workflow (WorkflowRunner), and agentkit (ProviderRegistry). The proxy project builds on top of these.

## zig-framework vnext Capabilities (What We Reuse)

| Framework Module | What It Provides | How We Use It |
|-----------------|-----------------|---------------|
| `runtime` | AppContext, TaskRunner, EventBus, ByteSink, StreamingBody, WebSocketBody | Core runtime assembly, async task execution, SSE/WS body contracts |
| `core` | Logger, LogSink, TraceContext, Validator, AppError | Structured logging, request tracing, config validation |
| `config` | ConfigStore, ConfigWritePipeline, ConfigLoader, ConfigChangeLog | JSON config loading, hot-reload, change detection, write-back |
| `observability` | Observer, MetricsObserver, RequestTrace, MethodTrace, SummaryTrace | Request metrics, provider call tracing |
| `effects` | HttpClient, FileSystem, EnvProvider, Clock, EffectsRuntime | Outbound HTTP to upstream AI APIs, file I/O for token storage, env vars |
| `contracts` | Envelope, AppError, CapabilityManifest | Structured API responses, error model |
| `app` | CommandDispatcher, CommandRegistry, CommandContext | Management API commands, CLI commands |
| `tooling` | ToolRegistry, ToolRunner, CommandSurface | Management tools, extensibility |
| `workflow` | WorkflowRunner, WorkflowStep (command, shell, retry, emit_event) | OAuth flow orchestration, multi-step auth sequences |
| `agentkit` | ProviderDefinition, ProviderHealth, ProviderRegistry | AI provider registration, health tracking, model listing |
| `servicekit` | Empty scaffold — **we extend this** | HTTP server, router, middleware, SSE, WebSocket |

## What We Build (New Code in zig-proxy-api)

### Layer 1: HTTP Server (extends framework servicekit pattern)

The framework's `servicekit` is reserved for runtime host / service abstractions. We build our HTTP server module within our own project, following the framework's patterns but not modifying the framework itself.

```
src/
├── server/
│   ├── http_server.zig      # Listen, accept, graceful shutdown, AppContext integration
│   ├── router.zig            # Radix tree: static, :param, *wildcard, route groups
│   ├── context.zig           # Per-request context: read body/headers/query, write JSON/SSE/WS
│   ├── middleware.zig         # Middleware chain: CORS, auth, request_logging, request_id, recovery
│   ├── sse.zig               # SSE streaming writer with keep-alive
│   └── websocket.zig         # WebSocket upgrade and frame handling
```

### Layer 2: Configuration

```
src/
├── config/
│   ├── proxy_config.zig      # Full config struct (port, host, TLS, providers, auth, etc.)
│   ├── loader.zig            # JSON config file loading using framework ConfigLoader
│   ├── watcher.zig           # File change detection, hot-reload via framework EventBus
│   └── diff.zig              # Config diff computation for incremental apply
```

JSON format (not YAML). Uses `std.json` for parsing. Framework's `ConfigStore` + `ConfigWritePipeline` for runtime config management.

### Layer 3: Authentication

```
src/
├── auth/
│   ├── manager.zig           # Auth manager: token lifecycle, refresh scheduling
│   ├── oauth_flow.zig        # OAuth flow using framework WorkflowRunner
│   ├── token_store.zig       # File-based token persistence using framework FileSystem
│   ├── api_key.zig           # API key validation for inbound requests
│   └── providers/
│       ├── claude.zig         # Claude OAuth (PKCE, token refresh)
│       ├── codex.zig          # OpenAI Codex OAuth (device flow + standard)
│       ├── gemini.zig         # Gemini OAuth
│       ├── qwen.zig           # Qwen OAuth
│       ├── kimi.zig           # Kimi OAuth
│       ├── iflow.zig          # iFlow OAuth
│       ├── antigravity.zig    # Antigravity OAuth
│       └── vertex.zig         # Vertex credentials
```

OAuth flows orchestrated via `workflow.WorkflowRunner` (retry, emit_event steps). Token storage via `effects.FileSystem`.

### Layer 4: Protocol Translators

```
src/
├── translator/
│   ├── registry.zig          # Translator registry: format pairs → transform functions
│   ├── pipeline.zig          # Translation pipeline: source → target with chaining
│   ├── types.zig             # Format enum, RequestTransform, ResponseTransform signatures
│   └── formats/
│       ├── openai.zig         # OpenAI chat/completions/responses format
│       ├── claude.zig         # Claude messages format
│       ├── gemini.zig         # Gemini generateContent format
│       ├── gemini_cli.zig     # Gemini CLI internal format
│       ├── codex.zig          # Codex format (HTTP + WebSocket)
│       └── antigravity.zig    # Antigravity format
```

Full 6-way translation matrix: OpenAI ↔ Claude ↔ Gemini ↔ Codex ↔ Antigravity ↔ Gemini-CLI. Supports stream and non-stream transforms. Thinking/reasoning content conversion.

### Layer 5: Executors

```
src/
├── executor/
│   ├── types.zig             # Request, Response, Options structs
│   ├── base.zig              # Base executor: HTTP request building, stream forwarding, retry
│   └── providers/
│       ├── claude.zig         # Claude API executor
│       ├── gemini.zig         # Gemini API executor
│       ├── gemini_vertex.zig  # Vertex AI executor
│       ├── gemini_cli.zig     # Gemini CLI executor
│       ├── codex.zig          # Codex HTTP executor
│       ├── codex_ws.zig       # Codex WebSocket executor
│       ├── qwen.zig           # Qwen executor
│       ├── kimi.zig           # Kimi executor
│       ├── iflow.zig          # iFlow executor
│       ├── antigravity.zig    # Antigravity executor
│       ├── openai_compat.zig  # OpenAI-compatible provider executor
│       └── aistudio.zig       # AI Studio executor
```

Each executor uses `effects.HttpClient` for outbound requests. Streaming via framework's `ByteSink` / `StreamingBody`. Provider registration via `agentkit.ProviderRegistry`.

### Layer 6: Scheduling & Load Balancing

```
src/
├── scheduler/
│   ├── conductor.zig         # Main scheduler: credential selection, retry orchestration
│   ├── selector.zig          # Credential selector: round-robin, fill-first strategies
│   ├── cooldown.zig          # Quota exceeded cooldown with exponential backoff
│   ├── model_registry.zig    # Model definitions, aliases, excluded models, wildcard matching
│   └── model_alias.zig       # Per-channel OAuth model alias mapping
```

### Layer 7: Storage Backends

```
src/
├── store/
│   ├── git_store.zig         # Git-based credential/state storage
│   ├── postgres_store.zig    # PostgreSQL storage
│   └── object_store.zig      # Object storage (S3-compatible)
```

All use `effects.FileSystem` / `effects.HttpClient` / `effects.ProcessRunner` for I/O.

### Layer 8: Management API

```
src/
├── management/
│   ├── handler.zig           # Management API handlers (auth, config, logs, usage)
│   ├── asset_updater.zig     # Control panel asset download from GitHub
│   └── routes.zig            # Management route registration
```

Exposed via framework `CommandDispatcher` + our HTTP router.

### Layer 9: TUI

```
src/
├── tui/
│   ├── app.zig               # TUI application shell, tab navigation
│   ├── dashboard.zig         # Dashboard tab
│   ├── auth_tab.zig          # Auth management tab
│   ├── config_tab.zig        # Config editor tab
│   ├── logs_tab.zig          # Log viewer tab
│   ├── usage_tab.zig         # Usage statistics tab
│   ├── oauth_tab.zig         # OAuth management tab
│   ├── keys_tab.zig          # API keys tab
│   ├── styles.zig            # TUI styling/colors
│   └── i18n.zig              # Internationalization (EN, CN, JA)
```

Built with ANSI escape sequences. Communicates with server via management API.

### Layer 10: Entry Point

```
src/
├── main.zig                  # CLI entry: arg parsing, signal handling, graceful shutdown
```

## HTTP Server Design (Layer 1 Detail)

### Core Types

- `HttpServer` — Manages listen, accept loop, graceful shutdown. Holds `*AppContext` reference.
- `Router` — Radix tree routing. Supports `GET/POST` method matching, path params (`:param`), wildcards (`*action`), route groups with shared middleware.
- `Context` — Per-request context. Read body/headers/query/params, write JSON/text/HTML/raw/SSE/WebSocket. Access AppContext, Logger with request_id.
- `Middleware` — `fn(*Context, Handler) anyerror!void`. Chainable, short-circuit capable.
- `SseWriter` — `writeEvent()`, `writeKeepAlive()`, `flush()`.
- `WebSocketConn` — `readMessage()`, `writeMessage()`, `close()`.

### Router API

```zig
var router = Router.init(allocator);

var v1 = router.group("/v1", &.{authMiddleware});
v1.get("/models", modelsHandler);
v1.post("/chat/completions", chatHandler);
v1.post("/messages", claudeHandler);

var v1beta = router.group("/v1beta", &.{authMiddleware});
v1beta.post("/models/*action", geminiHandler);

router.get("/api/provider/:provider/v1/*rest", providerRouteHandler);
```

### Middleware Stack

| Middleware | Purpose |
|-----------|---------|
| `request_id` | Generate request_id, inject into framework TraceContext |
| `recovery` | Catch handler errors, return 500 |
| `cors` | CORS preflight and response headers |
| `request_logging` | Request/response logging via framework Logger |
| `auth` | API Key / Management Key verification |

### Concurrency

- Based on `std.http.Server` with epoll/kqueue I/O multiplexing
- Request handlers execute in thread pool
- Context is stack-allocated, freed on request completion

### AppContext Integration

- Each request creates a `RequestTrace` bound to Context
- `ctx.logger()` returns Logger with request_id
- `ctx.appContext()` accesses EventBus, ConfigStore, etc.
- Request completion emits metrics to Observer

### Keep-Alive

For TUI heartbeat: `/keep-alive` endpoint with configurable timeout and shutdown callback.

## Sub-Project Decomposition & Order

| # | Sub-Project | Dependencies | Description |
|---|-------------|-------------|-------------|
| 1 | Project scaffold + HTTP server | zig-framework | build.zig, dependency setup, Router, Middleware, SSE, WebSocket |
| 2 | Configuration system | #1 | JSON config loading, hot-reload, change detection |
| 3 | Authentication system | #2 | OAuth flows, token storage/refresh, API Key auth |
| 4 | Protocol translators | #2 | 6-way format translation matrix |
| 5 | Executor layer | #3, #4 | Per-provider executors, stream forwarding |
| 6 | Scheduling & load balancing | #3, #5 | Multi-account rotation, quota management, model aliases |
| 7 | Storage backends | #2 | Git store, PostgreSQL store, Object store |
| 8 | Management API | #2, #3, #6 | Remote management endpoints, panel assets |
| 9 | TUI terminal interface | #2, #3, #6 | Full terminal UI with tabs |
| 10 | Integration & entry point | All | main, CLI args, signal handling, graceful shutdown |

Implementation order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

## Key Design Decisions

1. **Independent project** — `zig-proxy-api` is its own repo, references `zig-framework` as a Zig dependency
2. **JSON config** — Uses `std.json`, no YAML dependency
3. **vnext branch** — Based on `codex/framework-tooling-runtime-vnext` for effects, tooling, workflow, agentkit
4. **No new framework modules** — We don't modify zig-framework; all proxy code lives in our project
5. **Reuse framework patterns** — ProviderRegistry for providers, WorkflowRunner for OAuth, HttpClient for outbound, ByteSink/StreamingBody for streaming
6. **Native binary only** — No Docker; leverage Zig cross-compilation
