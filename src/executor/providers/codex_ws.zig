const std = @import("std");
const types = @import("../types.zig");

pub const CodexWsExecutor = struct {
    base_url: []const u8 = "wss://api.openai.com",
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

    fn executeErased(_: *anyopaque, _: std.mem.Allocator, _: types.Request, _: types.Options) anyerror!types.Response {
        return .{ .status_code = 501, .payload = "{\"error\":\"codex_ws requires WebSocket transport, not supported via HTTP executor\"}" };
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "codex_ws";
    }
};
