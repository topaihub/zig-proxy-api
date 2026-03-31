const std = @import("std");
const framework = @import("framework");

pub const server = @import("server/root.zig");
pub const config = @import("config/root.zig");
pub const auth = @import("auth/root.zig");
pub const translator = @import("translator/root.zig");
pub const executor = @import("executor/root.zig");
pub const scheduler = @import("scheduler/root.zig");
pub const store = @import("store/root.zig");

fn rootHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{ .message = "CLI Proxy API Server (Zig)", .version = "0.1.0" });
}

fn modelsHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{ .object = "list", .data = &[_]struct { id: []const u8, object: []const u8 }{
        .{ .id = "gemini-2.5-pro", .object = "model" },
        .{ .id = "claude-sonnet-4", .object = "model" },
    } });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var loaded = config.loadFromFile("config.json", allocator) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (loaded) |*l| l.deinit();
    const cfg = if (loaded) |l| l.config else config.Config{};

    const host = if (cfg.host.len > 0) cfg.host else "127.0.0.1";

    var app_ctx = try framework.AppContext.init(allocator, .{});
    defer app_ctx.deinit();

    var srv = server.HttpServer.init(allocator, .{
        .host = host,
        .port = cfg.port,
        .app_context = &app_ctx,
    });
    defer srv.deinit();

    srv.use(server.middleware.cors);
    srv.use(server.middleware.recovery);

    srv.router.get("/", rootHandler);
    srv.router.get("/v1/models", modelsHandler);

    var log = app_ctx.logger.subsystem("server");
    log.info("server starting", &.{ framework.LogField.string("host", host), framework.LogField.int("port", @intCast(cfg.port)) });

    try srv.listenAndServe();
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}

test {
    std.testing.refAllDecls(@This());
}
