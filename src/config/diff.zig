const std = @import("std");
const types = @import("types.zig");
const Config = types.Config;

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
    any_changed: bool = false,
};

pub fn diff(old: *const Config, new: *const Config) ConfigChanges {
    var c = ConfigChanges{};
    c.port_changed = old.port != new.port;
    c.host_changed = !std.mem.eql(u8, old.host, new.host);
    c.debug_changed = old.debug != new.debug;
    c.tls_changed = old.tls.enable != new.tls.enable or
        !std.mem.eql(u8, old.tls.cert, new.tls.cert) or
        !std.mem.eql(u8, old.tls.key, new.tls.key);
    c.api_keys_changed = old.api_keys.len != new.api_keys.len;
    c.proxy_url_changed = !std.mem.eql(u8, old.proxy_url, new.proxy_url);
    c.routing_changed = !std.mem.eql(u8, old.routing.strategy, new.routing.strategy);
    c.gemini_keys_changed = old.gemini_api_key.len != new.gemini_api_key.len;
    c.claude_keys_changed = old.claude_api_key.len != new.claude_api_key.len;
    c.codex_keys_changed = old.codex_api_key.len != new.codex_api_key.len;
    c.openai_compat_changed = old.openai_compatibility.len != new.openai_compatibility.len;
    c.vertex_keys_changed = old.vertex_api_key.len != new.vertex_api_key.len;
    c.any_changed = c.port_changed or c.host_changed or c.debug_changed or
        c.tls_changed or c.api_keys_changed or c.proxy_url_changed or
        c.routing_changed or c.gemini_keys_changed or c.claude_keys_changed or
        c.codex_keys_changed or c.openai_compat_changed or c.vertex_keys_changed;
    return c;
}

test "diff detects port change" {
    var old = Config{};
    var new = Config{};
    new.port = 9000;
    const changes = diff(&old, &new);
    try std.testing.expect(changes.port_changed);
    try std.testing.expect(changes.any_changed);
    try std.testing.expect(!changes.debug_changed);
}

test "diff detects no changes" {
    var cfg = Config{};
    const changes = diff(&cfg, &cfg);
    try std.testing.expect(!changes.any_changed);
}
