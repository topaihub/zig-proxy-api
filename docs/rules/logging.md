# Logging Rules

## Mandatory Rules

1. **HTTP entry points → RequestTrace** — wrap in `request_trace.begin()` / `complete()`
2. **Business methods → MethodTrace** — wrap in `MethodTrace.begin()` / `finishSuccess()` or `finishError()`
3. **External calls → StepTrace** — wrap in `StepTrace.begin()` / `finish()`
4. **State changes → Structured logging** — use `logger.subsystem("x").info("msg", &.{LogField...})`

## Forbidden

- NEVER use `std.debug.print` or `std.log` — use framework Logger
- NEVER put variable values in message strings — use LogField
- NEVER log sensitive data (tokens, keys, passwords) without redaction
- NEVER skip logging in error paths

## Subsystem Naming

Slash-separated lowercase: `server/http`, `auth/oauth`, `executor/gemini`, `translator/openai_gemini`, `config/loader`, `scheduler/selector`, `management/api`

## Thresholds

| Operation | ms |
|-----------|-----|
| HTTP request total | 30000 |
| Provider API call | 5000 |
| Translation | 100 |
| Config reload | 1000 |
| Auth token refresh | 5000 |
| File I/O | 500 |

## Logger Pattern for New Modules

```zig
pub const MyModule = struct {
    logger: ?*framework.Logger = null,
    pub fn setLogger(self: *MyModule, l: *framework.Logger) void { self.logger = l; }
};
```

Wire in main.zig: `my_module.setLogger(app_ctx.logger);`

## Full Guide

See `docs/logging-guide.md` for templates, decision tree, and examples.
