const std = @import("std");
const framework = @import("framework");

pub const ManagementClient = struct {
    base_url: []const u8 = "http://127.0.0.1:8317",
    secret_key: []const u8 = "",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ManagementClient {
        return .{ .allocator = allocator };
    }

    pub fn setBaseUrl(self: *ManagementClient, url: []const u8) void {
        self.base_url = url;
    }

    pub fn setSecretKey(self: *ManagementClient, key: []const u8) void {
        self.secret_key = key;
    }

    pub fn health(self: *ManagementClient) ![]u8 {
        return self.request("/v0/management/health");
    }

    pub fn authList(self: *ManagementClient) ![]u8 {
        return self.request("/v0/management/auth/list");
    }

    pub fn configGet(self: *ManagementClient) ![]u8 {
        return self.request("/v0/management/config");
    }

    fn request(self: *ManagementClient, path: []const u8) ![]u8 {
        var client = framework.NativeHttpClient.init(null);
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        defer self.allocator.free(url);
        const response = try client.send(self.allocator, .{
            .method = .GET,
            .url = url,
            .headers = if (self.secret_key.len > 0) &.{
                .{ .name = "X-Management-Key", .value = self.secret_key },
            } else &.{},
            .body = null,
        });
        return response.body orelse error.EmptyResponse;
    }

    pub fn deinit(self: *ManagementClient) void {
        _ = self;
    }
};

test "management client initializes" {
    var c = ManagementClient.init(std.testing.allocator);
    defer c.deinit();
    try std.testing.expectEqualStrings("http://127.0.0.1:8317", c.base_url);
}
