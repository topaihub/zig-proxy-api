const std = @import("std");
const server = @import("../server/root.zig");

const success_html = "<html><head><meta charset=\"utf-8\"><title>Authentication successful</title><script>setTimeout(function(){window.close();},5000);</script></head><body><h1>Authentication successful!</h1><p>You can close this window.</p></body></html>";

var pending_states: [16]PendingState = @splat(PendingState{});
var pending_count: u8 = 0;

pub const PendingState = struct {
    provider: []const u8 = "",
    state: []const u8 = "",
    code: []const u8 = "",
    error_msg: []const u8 = "",
    completed: bool = false,
};

pub fn addPendingState(provider_name: []const u8, state: []const u8) void {
    if (pending_count < pending_states.len) {
        pending_states[pending_count] = .{ .provider = provider_name, .state = state };
        pending_count += 1;
    }
}

pub fn checkPendingState(state: []const u8) ?*PendingState {
    for (pending_states[0..pending_count]) |*ps| {
        if (std.mem.eql(u8, ps.state, state) and ps.completed) return ps;
    }
    return null;
}

pub fn registerCallbackRoutes(router: *server.Router) void {
    router.get("/anthropic/callback", anthropicCallback);
    router.get("/codex/callback", codexCallback);
    router.get("/google/callback", googleCallback);
    router.get("/iflow/callback", iflowCallback);
    router.get("/antigravity/callback", antigravityCallback);
}

fn anthropicCallback(ctx: *server.Context) anyerror!void {
    handleCallback(ctx, "anthropic");
}
fn codexCallback(ctx: *server.Context) anyerror!void {
    handleCallback(ctx, "codex");
}
fn googleCallback(ctx: *server.Context) anyerror!void {
    handleCallback(ctx, "gemini");
}
fn iflowCallback(ctx: *server.Context) anyerror!void {
    handleCallback(ctx, "iflow");
}
fn antigravityCallback(ctx: *server.Context) anyerror!void {
    handleCallback(ctx, "antigravity");
}

fn handleCallback(ctx: *server.Context, provider_name: []const u8) void {
    const code = ctx.query("code") orelse "";
    const state = ctx.query("state") orelse "";
    const err_str = ctx.query("error") orelse "";

    for (pending_states[0..pending_count]) |*ps| {
        if (std.mem.eql(u8, ps.provider, provider_name) and std.mem.eql(u8, ps.state, state)) {
            ps.code = code;
            ps.error_msg = err_str;
            ps.completed = true;
            break;
        }
    }

    ctx.html(.ok, success_html) catch {};
}

// Reset global state for tests
fn resetState() void {
    pending_states = @splat(PendingState{});
    pending_count = 0;
}

test "add and check pending state" {
    resetState();
    addPendingState("claude", "state123");
    try std.testing.expect(checkPendingState("state123") == null); // not completed yet
}

test "completed pending state is found" {
    resetState();
    addPendingState("claude", "abc");
    pending_states[0].completed = true;
    try std.testing.expect(checkPendingState("abc") != null);
}
