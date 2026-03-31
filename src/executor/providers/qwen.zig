const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const QwenExecutor = struct {
    base_url: []const u8 = "https://dashscope.aliyuncs.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) QwenExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *QwenExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *QwenExecutor = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "{s}/api/v1/chat/completions", .{self.base_url});
        const auth_value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.api_key});

        var client = framework.NativeHttpClient.init(null);
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
        return "qwen";
    }
};

test "qwen executor has correct defaults" {
    var exec = QwenExecutor.init("test-key");
    try std.testing.expectEqualStrings("qwen", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://dashscope.aliyuncs.com", exec.base_url);
}
