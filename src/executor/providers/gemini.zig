const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const GeminiExecutor = struct {
    base_url: []const u8 = "https://generativelanguage.googleapis.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) GeminiExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *GeminiExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, opts: types.Options) anyerror!types.Response {
        const self: *GeminiExecutor = @ptrCast(@alignCast(ptr));

        const action = if (opts.stream) "streamGenerateContent?alt=sse&" else "generateContent?";
        const url = try std.fmt.allocPrint(allocator, "{s}/v1beta/models/{s}:{s}key={s}", .{
            self.base_url, req.model, action, self.api_key,
        });

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
        return "gemini";
    }
};

test "gemini executor builds correct url" {
    var exec = GeminiExecutor.init("test-key");
    try std.testing.expectEqualStrings("gemini", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://generativelanguage.googleapis.com", exec.base_url);
}
