const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const GeminiCliExecutor = struct {
    base_url: []const u8 = "https://generativelanguage.googleapis.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) GeminiCliExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *GeminiCliExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *GeminiCliExecutor = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "{s}/v1beta/models/{s}:generateContent?key={s}", .{ self.base_url, req.model, self.api_key });

        var client = framework.NativeHttpClient.init(null);
        const response = try client.send(allocator, .{
            .method = .POST,
            .url = url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .body = req.payload,
        });

        return .{ .status_code = response.status_code, .payload = response.body };
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "gemini_cli";
    }
};

test "gemini_cli executor has correct defaults" {
    var exec = GeminiCliExecutor.init("test-key");
    try std.testing.expectEqualStrings("gemini_cli", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://generativelanguage.googleapis.com", exec.base_url);
}
