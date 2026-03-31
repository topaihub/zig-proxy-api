const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const OpenAICompatExecutor = struct {
    base_url: []const u8,
    api_key: []const u8 = "",

    pub fn init(base_url: []const u8, api_key: []const u8) OpenAICompatExecutor {
        return .{ .base_url = base_url, .api_key = api_key };
    }

    pub fn executor(self: *OpenAICompatExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *OpenAICompatExecutor = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "{s}/v1/chat/completions", .{self.base_url});
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
        return "openai_compat";
    }
};

test "openai_compat executor has correct defaults" {
    var exec = OpenAICompatExecutor.init("https://localhost:8080", "test-key");
    try std.testing.expectEqualStrings("openai_compat", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://localhost:8080", exec.base_url);
}
