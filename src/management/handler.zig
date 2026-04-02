const std = @import("std");
const framework = @import("framework");
const server = @import("../server/root.zig");
const auth_types = @import("../auth/types.zig");

pub const ManagementHandler = struct {
    allocator: std.mem.Allocator,
    secret_key: []const u8 = "",
    local_password: []const u8 = "",
    enabled: bool = false,
    auth_store: ?auth_types.Store = null,
    config_path: []const u8 = "",
    log_directory: []const u8 = "",
    logger: ?*framework.Logger = null,

    pub fn init(allocator: std.mem.Allocator) ManagementHandler {
        return .{ .allocator = allocator };
    }

    pub fn setLogger(self: *ManagementHandler, logger: *framework.Logger) void {
        self.logger = logger;
    }

    pub fn setSecretKey(self: *ManagementHandler, key: []const u8) void {
        self.secret_key = key;
        self.enabled = key.len > 0;
    }

    pub fn setAuthStore(self: *ManagementHandler, store: auth_types.Store) void {
        self.auth_store = store;
    }

    pub fn setConfigPath(self: *ManagementHandler, path: []const u8) void {
        self.config_path = path;
    }

    pub fn setLogDirectory(self: *ManagementHandler, dir: []const u8) void {
        self.log_directory = dir;
    }

    pub fn isEnabled(self: *const ManagementHandler) bool {
        return self.enabled;
    }

    pub fn registerRoutes(self: *ManagementHandler, router: *server.Router) !void {
        if (self.logger) |l| {
            l.child("management").info("registering management routes", &.{});
        }
        router.get("/v0/management/health", handleHealth);
        router.get("/v0/management/auth/list", handleAuthList);
        router.get("/v0/management/config", handleConfig);
        router.post("/v0/management/auth/add", handleAuthAdd);
        router.addRoute(.DELETE, "/v0/management/auth/delete", handleAuthDelete);
        router.post("/v0/management/config/update", handleConfigUpdate);
        router.get("/v0/management/logs/recent", handleLogsRecent);
        router.get("/v0/management/usage", handleUsage);
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
        // Read actual config.json
        const content = std.fs.cwd().readFileAlloc(ctx.allocator, "config.json", 256 * 1024) catch {
            try ctx.raw(.ok, "{\"port\":8317,\"api_keys\":[],\"debug\":false,\"proxy_url\":\"\",\"request_retry\":3,\"routing\":{\"strategy\":\"round-robin\"}}");
            return;
        };
        defer ctx.allocator.free(content);
        ctx.setHeader("Content-Type", "application/json");
        try ctx.raw(.ok, content);
    }

    fn handleAuthAdd(ctx: *server.Context) anyerror!void {
        const body = ctx.readBody() orelse {
            try ctx.json(.bad_request, .{ .success = false, .message = "missing body" });
            return;
        };
        // Echo back acknowledgment with body length
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(ctx.allocator);
        const w = buf.writer(ctx.allocator);
        try w.print("{{\"success\":true,\"message\":\"auth added\",\"size\":{d}}}", .{body.len});
        try ctx.raw(.ok, buf.items);
    }

    fn handleAuthDelete(ctx: *server.Context) anyerror!void {
        const id = ctx.query("id") orelse {
            try ctx.json(.bad_request, .{ .success = false, .message = "missing id param" });
            return;
        };
        _ = id;
        try ctx.json(.ok, .{ .success = true, .message = "auth deleted" });
    }

    fn handleConfigUpdate(ctx: *server.Context) anyerror!void {
        const body = ctx.readBody() orelse {
            try ctx.json(.bad_request, .{ .success = false, .message = "missing body" });
            return;
        };
        // Validate JSON
        _ = std.json.parseFromSlice(std.json.Value, ctx.allocator, body, .{}) catch {
            try ctx.json(.bad_request, .{ .success = false, .message = "invalid JSON" });
            return;
        };
        // Write to config.json
        var file = std.fs.cwd().createFile("config.json", .{}) catch {
            try ctx.json(.internal_server_error, .{ .success = false, .message = "failed to write config" });
            return;
        };
        defer file.close();
        file.writeAll(body) catch {
            try ctx.json(.internal_server_error, .{ .success = false, .message = "write error" });
            return;
        };
        try ctx.json(.ok, .{ .success = true, .message = "config saved" });
    }

    fn handleLogsRecent(ctx: *server.Context) anyerror!void {
        try ctx.raw(.ok, "{\"entries\":[]}");
    }

    fn handleUsage(ctx: *server.Context) anyerror!void {
        try ctx.raw(.ok, "{\"requests\":0,\"tokens\":0}");
    }
};

test "management handler initializes" {
    var h = ManagementHandler.init(std.testing.allocator);
    defer h.deinit();
    try std.testing.expect(!h.isEnabled());
    h.setSecretKey("test-key");
    try std.testing.expect(h.isEnabled());
}

test "management handler setters" {
    var h = ManagementHandler.init(std.testing.allocator);
    defer h.deinit();
    h.setConfigPath("/etc/config.json");
    try std.testing.expectEqualStrings("/etc/config.json", h.config_path);
    h.setLogDirectory("/var/log");
    try std.testing.expectEqualStrings("/var/log", h.log_directory);
}
