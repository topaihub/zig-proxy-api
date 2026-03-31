const std = @import("std");
const framework = @import("framework");
const types = @import("../types.zig");

pub const VertexExecutor = struct {
    base_url: []const u8 = "https://us-central1-aiplatform.googleapis.com",
    api_key: []const u8 = "",

    pub fn init(api_key: []const u8) VertexExecutor {
        return .{ .api_key = api_key };
    }

    pub fn executor(self: *VertexExecutor) types.Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = types.Executor.VTable{
        .execute = executeErased,
        .provider_name = nameErased,
    };

    fn executeErased(ptr: *anyopaque, allocator: std.mem.Allocator, req: types.Request, _: types.Options) anyerror!types.Response {
        const self: *VertexExecutor = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "{s}/v1beta/models/{s}:generateContent", .{ self.base_url, req.model });

        var client = framework.NativeHttpClient.init(null);
        const response = try client.send(allocator, .{
            .method = .POST,
            .url = url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-goog-api-key", .value = self.api_key },
            },
            .body = req.payload,
        });

        return .{ .status_code = response.status_code, .payload = response.body };
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "gemini_vertex";
    }
};

test "vertex executor has correct defaults" {
    var exec = VertexExecutor.init("test-key");
    try std.testing.expectEqualStrings("gemini_vertex", exec.executor().providerName());
    try std.testing.expectEqualStrings("https://us-central1-aiplatform.googleapis.com", exec.base_url);
}
