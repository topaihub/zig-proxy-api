const std = @import("std");
const framework = @import("framework");
const types = @import("types.zig");

pub const BaseExecutor = struct {
    provider: []const u8,
    base_url: []const u8,
    api_key: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, provider: []const u8, base_url: []const u8, api_key: []const u8) BaseExecutor {
        return .{ .allocator = allocator, .provider = provider, .base_url = base_url, .api_key = api_key };
    }

    pub fn executor(self: *BaseExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    pub fn deinit(self: *BaseExecutor) void {
        _ = self;
    }

    const vtable = types.Executor.VTable{
        .execute = execute,
        .provider_name = providerName,
    };

    fn execute(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *BaseExecutor = @ptrCast(@alignCast(ptr));
        var client = framework.NativeHttpClient.init(null);
        const auth_value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.api_key});
        const response = try client.send(allocator, .{
            .method = .POST,
            .url = self.base_url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Authorization", .value = auth_value },
            },
            .body = req.payload,
        });
        return .{ .status_code = response.status_code, .payload = response.body };
    }

    fn providerName(ptr: *anyopaque) []const u8 {
        const self: *BaseExecutor = @ptrCast(@alignCast(ptr));
        return self.provider;
    }
};

test "base executor initializes" {
    var base = BaseExecutor.init(std.testing.allocator, "test", "https://api.example.com", "sk-test");
    defer base.deinit();
    const exec = base.executor();
    try std.testing.expectEqualStrings("test", exec.providerName());
}
