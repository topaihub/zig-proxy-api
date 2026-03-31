const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const AiStudioExecutor = struct {
    base_url: []const u8 = "https://aistudio.google.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) AiStudioExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *AiStudioExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *AiStudioExecutor = @ptrCast(@alignCast(ptr));

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
        return "aistudio";
    }
};

test "aistudio executor has correct defaults" {
    var exec = AiStudioExecutor.init("test-key");
    try std.testing.expectEqualStrings("aistudio", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://aistudio.google.com", exec.base_url);
}
