const std = @import("std");
const framework = @import("framework");

pub const server = @import("server/root.zig");

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

    var app_ctx = try framework.AppContext.init(allocator, .{});
    defer app_ctx.deinit();

    var srv = server.HttpServer.init(allocator, .{
        .host = "127.0.0.1",
        .port = 8317,
        .app_context = &app_ctx,
    });
    defer srv.deinit();

    srv.use(server.middleware.cors);
    srv.use(server.middleware.recovery);

    srv.router.get("/", rootHandler);
    srv.router.get("/v1/models", modelsHandler);

    var log = app_ctx.logger.subsystem("server");
    log.info("listening on 127.0.0.1:8317", &.{});

    try srv.listenAndServe();
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}

test {
    std.testing.refAllDecls(@This());
}
