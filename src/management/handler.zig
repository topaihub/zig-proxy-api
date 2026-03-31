const std = @import("std");
const server = @import("../server/root.zig");

pub const ManagementHandler = struct {
    allocator: std.mem.Allocator,
    secret_key: []const u8 = "",
    local_password: []const u8 = "",
    enabled: bool = false,

    pub fn init(allocator: std.mem.Allocator) ManagementHandler {
        return .{ .allocator = allocator };
    }

    pub fn setSecretKey(self: *ManagementHandler, key: []const u8) void {
        self.secret_key = key;
        self.enabled = key.len > 0;
    }

    pub fn isEnabled(self: *const ManagementHandler) bool {
        return self.enabled;
    }

    pub fn registerRoutes(self: *ManagementHandler, router: *server.Router) !void {
        _ = self;
        router.get("/v0/management/health", handleHealth);
        router.get("/v0/management/auth/list", handleAuthList);
        router.get("/v0/management/config", handleConfig);
    }

    pub fn deinit(self: *ManagementHandler) void {
        _ = self;
    }

    fn handleHealth(ctx: *server.Context) anyerror!void {
        try ctx.json(.ok, .{ .status = "ok" });
    }

    fn handleAuthList(ctx: *server.Context) anyerror!void {
        const empty = [_]@import("types.zig").AuthListEntry{};
        try ctx.json(.ok, .{ .entries = empty });
    }

    fn handleConfig(ctx: *server.Context) anyerror!void {
        try ctx.json(.ok, .{});
    }
};

test "management handler initializes" {
    var h = ManagementHandler.init(std.testing.allocator);
    defer h.deinit();
    try std.testing.expect(!h.isEnabled());
    h.setSecretKey("test-key");
    try std.testing.expect(h.isEnabled());
}
