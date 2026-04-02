# zig-proxy-api

A high-performance AI CLI proxy server written in Zig. Provides OpenAI/Gemini/Claude/Codex compatible API endpoints, allowing any OpenAI-compatible client to use your AI subscriptions.

Zig rewrite of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), built on [zig-framework](https://github.com/topaihub/zig-framework).

## Features

- **Multi-protocol API** — OpenAI, Claude, Gemini, Codex compatible endpoints
- **12 AI providers** — Gemini, Claude, Codex, Qwen, Kimi, iFlow, Antigravity, Vertex, AIStudio, OpenAI-compat, and more
- **Protocol translation** — Automatic request/response conversion between formats
- **Multi-account load balancing** — Round-robin and fill-first credential rotation
- **Streaming** — SSE streaming with keep-alive support
- **Management panel** — Built-in web UI at `/management.html`
- **Single binary** — Zero runtime dependencies, cross-platform (Linux/macOS/Windows)

## Quick Start

### Download

Grab the latest binary from [Releases](https://github.com/topaihub/zig-proxy-api/releases), or build from source:

```bash
git clone https://github.com/topaihub/zig-proxy-api.git
cd zig-proxy-api
zig build -Doptimize=ReleaseSmall
./zig-out/bin/zig-proxy-api
```

### Configure

Create `config.json` in the same directory:

```json
{
    "port": 8317,
    "host": "",
    "api_keys": ["your-proxy-key"],
    "request_retry": 3,
    "routing": {
        "strategy": "round-robin"
    },
    "gemini_api_key": [
        {
            "api_key": "AIzaSy...",
            "base_url": "https://generativelanguage.googleapis.com"
        }
    ],
    "claude_api_key": [
        {
            "api_key": "sk-ant-...",
            "base_url": "https://api.anthropic.com"
        }
    ]
}
```

Or use the web management panel to configure: `http://127.0.0.1:8317/management.html`

### Run

```bash
./zig-proxy-api
# or with custom config:
./zig-proxy-api --config=myconfig.json --port=9000
```

### Use

```bash
# List models
curl http://127.0.0.1:8317/v1/models

# Chat (OpenAI format)
curl http://127.0.0.1:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-proxy-key" \
  -d '{"model":"gemini-2.5-pro","messages":[{"role":"user","content":"hello"}]}'

# Claude format
curl http://127.0.0.1:8317/v1/messages \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-proxy-key" \
  -d '{"model":"claude-sonnet-4","max_tokens":1024,"messages":[{"role":"user","content":"hello"}]}'

# Gemini format
curl -X POST "http://127.0.0.1:8317/v1beta/models/gemini-2.5-pro:generateContent" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-proxy-key" \
  -d '{"contents":[{"parts":[{"text":"hello"}]}]}'
```

### Use with AI Coding Tools

Set in your AI tool (Claude Code, Cursor, Cline, etc.):

| Setting | Value |
|---------|-------|
| API Base URL | `http://127.0.0.1:8317/v1` |
| API Key | Your proxy key from `config.json` |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Server info |
| GET | `/v1/models` | List all models |
| POST | `/v1/chat/completions` | OpenAI Chat Completions |
| POST | `/v1/completions` | OpenAI Completions |
| POST | `/v1/messages` | Claude Messages |
| POST | `/v1/messages/count_tokens` | Claude Token Count |
| POST | `/v1/responses` | Codex Responses |
| GET | `/v1beta/models` | Gemini Models |
| POST | `/v1beta/models/*:generateContent` | Gemini Generate |
| GET | `/management.html` | Management Panel |

## Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `port` | number | 8317 | Server port |
| `host` | string | "" | Bind address ("" = all interfaces) |
| `api_keys` | string[] | [] | Client authentication keys |
| `debug` | bool | false | Debug logging |
| `proxy_url` | string | "" | Upstream proxy (socks5/http) |
| `request_retry` | number | 3 | Retry count on failure |
| `routing.strategy` | string | "round-robin" | Credential selection strategy |
| `gemini_api_key` | array | [] | Gemini API key configs |
| `claude_api_key` | array | [] | Claude API key configs |
| `codex_api_key` | array | [] | Codex API key configs |
| `openai_compatibility` | array | [] | OpenAI-compatible provider configs |

## Building

Requires [Zig 0.15.2](https://ziglang.org/download/):

```bash
zig build              # Debug build
zig build -Doptimize=ReleaseSmall  # Release build
zig build test         # Run tests
```

Cross-compile:

```bash
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSmall
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSmall
```

## License

MIT
