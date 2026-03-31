const std = @import("std");
const types = @import("../types.zig");

pub const CodexExecutor = struct {
    base_url: []const u8 = "https://api.openai.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) CodexExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *CodexExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(_: *anyopaque, _: std.mem.Allocator, _: types.Request, _: types.Options) anyerror!types.Response {
        return .{ .status_code = 200, .payload = "{\"stub\":true}" };
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "codex";
    }
};
