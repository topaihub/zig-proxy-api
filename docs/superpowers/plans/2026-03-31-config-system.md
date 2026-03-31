# Sub-Project 2: Configuration System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** JSON-based configuration system for zig-proxy-api with full parity to CLIProxyAPI's config structure, hot-reload via file watching, and integration with framework's ConfigStore.

**Architecture:** A Zig struct hierarchy mirroring CLIProxyAPI's Config, parsed from JSON via `std.json`. File watcher detects changes and triggers reload via framework EventBus. Config diffing enables incremental apply.

**Tech Stack:** Zig 0.15.2, std.json, zig-framework (ConfigStore, ConfigWritePipeline, EventBus)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `src/config/root.zig` | Module exports |
| `src/config/types.zig` | All config struct definitions (Config, provider keys, TLS, routing, etc.) |
| `src/config/loader.zig` | Load JSON file, parse into Config, apply defaults |
| `src/config/watcher.zig` | File change detection, hot-reload trigger via EventBus |
| `src/config/diff.zig` | Config diff computation for incremental apply |

---

### Task 1: Config Types

**Files:**
- Create: `src/config/types.zig`
- Create: `src/config/root.zig`

- [ ] **Step 1: Write test for config defaults**

```zig
test "default config has expected values" {
    const cfg = Config{};
    try std.testing.expectEqual(@as(u16, 8317), cfg.port);
    try std.testing.expectEqualStrings("", cfg.host);
    try std.testing.expectEqual(false, cfg.debug);
    try std.testing.expectEqual(@as(u8, 3), cfg.request_retry);
}
```

- [ ] **Step 2: Implement all config structs**

Define the full Config struct hierarchy matching CLIProxyAPI. All fields use JSON-compatible types. Use `[]const u8` for strings, slices for arrays, optional pointers for nullable sub-structs.

Key structs:
- `Config` — top-level (host, port, tls, auth_dir, debug, api_keys, proxy_url, providers, etc.)
- `TlsConfig` — enable, cert, key
- `RemoteManagement` — allow_remote, secret_key, disable_control_panel
- `QuotaExceeded` — switch_project, switch_preview_model
- `RoutingConfig` — strategy
- `StreamingConfig` — keepalive_seconds, bootstrap_retries
- `GeminiKey` — api_key, prefix, base_url, proxy_url, models, headers, excluded_models
- `ClaudeKey` — api_key, prefix, base_url, proxy_url, models, headers, excluded_models, cloak
- `CodexKey` — api_key, prefix, base_url, websockets, proxy_url, models, headers, excluded_models
- `OpenAICompat` — name, prefix, base_url, api_key_entries, models, headers
- `VertexKey` — api_key, prefix, base_url, proxy_url, models, headers, excluded_models
- `AmpCode` — upstream_url, upstream_api_key, model_mappings, restrict_management_to_localhost
- `ModelEntry` — name, alias
- `CloakConfig` — mode, strict_mode, sensitive_words, cache_user_id
- `PayloadConfig` — default rules
- `OAuthModelAlias` — name, alias, fork
- `ClaudeHeaderDefaults`, `CodexHeaderDefaults`

- [ ] **Step 3: Create root.zig**

```zig
pub const types = @import("types.zig");
pub const Config = types.Config;
// ... export all public types
```

- [ ] **Step 4: Wire into main.zig**

Add `pub const config = @import("config/root.zig");` to main.zig.

- [ ] **Step 5: Run tests, commit**

```bash
zig build test
git add -A && git commit -m "feat(config): add configuration type definitions"
```

---

### Task 2: Config Loader

**Files:**
- Create: `src/config/loader.zig`
- Modify: `src/config/root.zig`

- [ ] **Step 1: Write test for loading config from JSON string**

```zig
test "load config from json string" {
    const json =
        \\{"port": 9000, "host": "127.0.0.1", "debug": true, "api-keys": ["key1", "key2"]}
    ;
    var cfg = try loadFromString(json, std.testing.allocator);
    defer cfg.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 9000), cfg.port);
    try std.testing.expectEqualStrings("127.0.0.1", cfg.host);
    try std.testing.expectEqual(true, cfg.debug);
}
```

- [ ] **Step 2: Write test for loading from file**

```zig
test "load config from file" {
    // Write a temp JSON file, load it, verify
    const tmp_path = "/tmp/zig-proxy-api-test-config.json";
    const content = "{\"port\": 7777}";
    {
        var f = try std.fs.cwd().createFile(tmp_path, .{});
        defer f.close();
        try f.writeAll(content);
    }
    defer std.fs.cwd().deleteFile(tmp_path) catch {};
    var cfg = try loadFromFile(tmp_path, std.testing.allocator);
    defer cfg.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 7777), cfg.port);
}
```

- [ ] **Step 3: Implement loader**

Two public functions:
- `loadFromString(json: []const u8, allocator) !Config` — parse JSON into Config using `std.json.parseFromSlice`
- `loadFromFile(path: []const u8, allocator) !Config` — read file, call loadFromString
- `Config.deinit(allocator)` — free parsed memory

Use `std.json.parseFromSlice(Config, allocator, json, .{ .allocate = .alloc_always })` for parsing. The parsed result holds allocated memory that must be freed.

Note: std.json in Zig 0.15.2 uses field names as-is. CLIProxyAPI uses kebab-case in JSON (e.g., "api-keys"). Zig struct fields use snake_case. You may need to check if std.json supports custom field name mapping, or use matching field names. If std.json doesn't support kebab-case mapping, use snake_case in the JSON format (our format, not YAML compat).

- [ ] **Step 4: Update root.zig, run tests, commit**

```bash
zig build test
git add -A && git commit -m "feat(config): add JSON config loader"
```

---

### Task 3: Config Watcher

**Files:**
- Create: `src/config/watcher.zig`
- Modify: `src/config/root.zig`

- [ ] **Step 1: Write test for watcher detecting file change**

```zig
test "watcher detects file modification" {
    // Create a temp config file
    // Create watcher
    // Modify the file
    // Call watcher.check() — should return true (changed)
    // Call watcher.check() again — should return false (no new change)
}
```

- [ ] **Step 2: Implement watcher**

```zig
pub const ConfigWatcher = struct {
    config_path: []const u8,
    auth_dir: []const u8,
    last_config_mtime: i128,
    last_auth_mtime: i128,
    allocator: std.mem.Allocator,

    pub fn init(allocator, config_path, auth_dir) !ConfigWatcher
    pub fn check(self) !bool  // returns true if any file changed
    pub fn deinit(self) void
};
```

Uses `std.fs.File.stat()` to get modification time. Compares with stored mtime.

- [ ] **Step 3: Update root.zig, run tests, commit**

```bash
zig build test
git add -A && git commit -m "feat(config): add file change watcher"
```

---

### Task 4: Config Diff

**Files:**
- Create: `src/config/diff.zig`
- Modify: `src/config/root.zig`

- [ ] **Step 1: Write test for diff detection**

```zig
test "diff detects port change" {
    var old = Config{};
    var new = Config{};
    new.port = 9000;
    const changes = diff(&old, &new);
    try std.testing.expect(changes.port_changed);
    try std.testing.expect(!changes.debug_changed);
}
```

- [ ] **Step 2: Implement diff**

```zig
pub const ConfigChanges = struct {
    port_changed: bool = false,
    host_changed: bool = false,
    debug_changed: bool = false,
    tls_changed: bool = false,
    api_keys_changed: bool = false,
    proxy_url_changed: bool = false,
    routing_changed: bool = false,
    gemini_keys_changed: bool = false,
    claude_keys_changed: bool = false,
    codex_keys_changed: bool = false,
    openai_compat_changed: bool = false,
    vertex_keys_changed: bool = false,
    oauth_aliases_changed: bool = false,
    oauth_excluded_changed: bool = false,
    any_changed: bool = false,
};

pub fn diff(old: *const Config, new: *const Config) ConfigChanges
```

Compare key fields. For slices (api_keys, provider keys), compare lengths as a quick check.

- [ ] **Step 3: Update root.zig, run tests, commit**

```bash
zig build test
git add -A && git commit -m "feat(config): add config diff computation"
```

---

### Task 5: Integration — Config in HttpServer

**Files:**
- Modify: `src/main.zig`

- [ ] **Step 1: Update main.zig to load config from file**

Add config loading to main():
- Try to load from "config.json" in current directory
- If not found, use defaults
- Pass config values to HttpServer (port, host)
- Log loaded config info

- [ ] **Step 2: Create example config.json**

Create `config.example.json` at project root with documented fields.

- [ ] **Step 3: Run tests, commit**

```bash
zig build test
git build
git add -A && git commit -m "feat(config): integrate config loading into server startup"
```
