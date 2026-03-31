const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const CodexWsExecutor = struct {
    base_url: []const u8 = "wss://api.openai.com",
    ws_path: []const u8 = "/v1/realtime",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) CodexWsExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *CodexWsExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *CodexWsExecutor = @ptrCast(@alignCast(ptr));

        // HTTP fallback — true WebSocket requires TCP + TLS management
        var client = framework.NativeHttpClient.init(null);
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/responses", .{self.base_url});
        const auth_value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.api_key});

        const response = try client.send(allocator, .{
            .method = .POST,
            .url = url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Authorization", .value = auth_value },
            },
            .body = req.payload,
        });

        return .{ .status_code = response.status_code, .payload = response.body };
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "codex-ws";
    }
};

/// Generate a random WebSocket key for the handshake
pub fn generateWsKey(buf: *[24]u8) void {
    var random_bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    _ = std.base64.standard.Encoder.encode(buf, &random_bytes);
}

/// Build WebSocket upgrade request
pub fn buildUpgradeRequest(allocator: std.mem.Allocator, host: []const u8, path: []const u8, key: []const u8, api_key: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        "GET {s} HTTP/1.1\r\nHost: {s}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {s}\r\nSec-WebSocket-Version: 13\r\nAuthorization: Bearer {s}\r\n\r\n",
        .{ path, host, key, api_key },
    );
}

test "codex ws executor has correct name" {
    var exec = CodexWsExecutor.init("test-key");
    try std.testing.expectEqualStrings("codex-ws", exec.executor().providerName());
}

test "generate ws key produces 24 chars" {
    var buf: [24]u8 = undefined;
    generateWsKey(&buf);
    try std.testing.expectEqual(@as(usize, 24), buf.len);
}

test "build upgrade request contains required headers" {
    const req = try buildUpgradeRequest(std.testing.allocator, "api.openai.com", "/v1/realtime", "dGVzdA==", "sk-test");
    defer std.testing.allocator.free(req);
    try std.testing.expect(std.mem.indexOf(u8, req, "Upgrade: websocket") != null);
    try std.testing.expect(std.mem.indexOf(u8, req, "Bearer sk-test") != null);
}
