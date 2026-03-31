const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const IflowExecutor = struct {
    base_url: []const u8 = "https://api.iflow.io",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) IflowExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *IflowExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *IflowExecutor = @ptrCast(@alignCast(ptr));

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
        return "iflow";
    }
};

test "iflow executor has correct defaults" {
    var exec = IflowExecutor.init("test-key");
    try std.testing.expectEqualStrings("iflow", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://api.iflow.io", exec.base_url);
}
