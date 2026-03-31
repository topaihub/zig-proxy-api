# AGENTS.md — zig-proxy-api Development Rules

## Logging Rules (MANDATORY)

Every code change MUST follow the framework logging conventions. Violations will be rejected in code review.

### Rule 1: HTTP/API entry points → RequestTrace

Any function that handles an inbound HTTP request MUST wrap the handler body in a `RequestTrace`:

```zig
var trace = try framework.observability.request_trace.begin(allocator, logger, .http, request_id, method, path, query);
defer trace.deinit();
// ... handle request ...
framework.observability.request_trace.complete(logger, &trace, status_code, error_code);
```

### Rule 2: Business methods → MethodTrace

Any method that performs a significant operation (translation, execution, auth flow, config write) MUST use `MethodTrace`:

```zig
var mt = try framework.MethodTrace.begin(allocator, logger, "Module.Method", input_summary, threshold_ms);
defer mt.deinit();
// ... do work ...
mt.finishSuccess("result_summary", false);
// or on error: mt.finishError("ErrorType", error_code, false);
```

### Rule 3: External calls → StepTrace

Any call to an external system (HTTP to AI provider, database, file I/O) MUST use `StepTrace`:

```zig
var st = try framework.StepTrace.begin(allocator, logger, "subsystem/operation", step_name, threshold_ms);
defer st.deinit();
// ... external call ...
st.finish(null); // or st.finish("ERROR_CODE");
```

### Rule 4: State changes → Structured logging

State changes (config reload, auth update, credential selection) MUST use structured logging with fields:

```zig
logger.subsystem("config").info("configuration reloaded", &.{
    framework.LogField.string("path", config_path),
    framework.LogField.boolean("changed", true),
});
```

### Rule 5: NEVER do these

- NEVER put variable values in the message string — use LogField instead
- NEVER use `std.debug.print` or `std.log` — use framework Logger
- NEVER skip logging in error paths
- NEVER log sensitive data (tokens, keys, passwords) without redaction

### Subsystem naming convention

Use slash-separated lowercase paths:
- `server/http`, `server/ws`
- `auth/oauth`, `auth/refresh`, `auth/callback`
- `config/loader`, `config/watcher`
- `executor/{provider}` (e.g., `executor/gemini`, `executor/claude`)
- `translator/{from}_{to}` (e.g., `translator/openai_gemini`)
- `scheduler/selector`, `scheduler/cooldown`
- `management/api`

### Threshold guidelines

| Operation | Threshold (ms) |
|-----------|---------------|
| HTTP request (total) | 30000 |
| Provider API call | 5000 |
| Translation | 100 |
| Config reload | 1000 |
| Auth token refresh | 5000 |
| File I/O | 500 |

## Code Style

- Follow existing patterns in the codebase
- Use vtable interfaces for polymorphism
- All public types need tests
- Use `std.json` for JSON, manual building with `ArrayListUnmanaged(u8)` for complex output
