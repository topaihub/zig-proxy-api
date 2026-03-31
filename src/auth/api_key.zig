const std = @import("std");
const Context = @import("../server/context.zig").Context;
const Handler = @import("../server/context.zig").Handler;

var configured_keys: []const []const u8 = &.{};

pub fn configure(keys: []const []const u8) void {
    configured_keys = keys;
}

pub fn middleware(ctx: *Context, next: Handler) anyerror!void {
    if (configured_keys.len == 0) return next(ctx);

    if (getKey(ctx)) |key| {
        for (configured_keys) |valid| {
            if (std.mem.eql(u8, key, valid)) return next(ctx);
        }
    }

    try ctx.json(.unauthorized, .{ .@"error" = .{ .message = "Invalid or missing API key", .type = "authentication_error" } });
}

fn getKey(ctx: *Context) ?[]const u8 {
    if (ctx.header("x-api-key")) |k| return k;
    if (ctx.header("authorization")) |auth| {
        const prefix = "Bearer ";
        if (std.mem.startsWith(u8, auth, prefix)) return auth[prefix.len..];
    }
    return null;
}

test "api key auth rejects when no key provided" {
    configure(&.{"test-key"});
    var ctx = Context.initTest(.GET, "/v1/models", std.testing.allocator);
    defer ctx.deinit();
    const final = struct {
        fn h(_: *Context) anyerror!void {}
    }.h;
    try middleware(&ctx, final);
    try std.testing.expectEqual(std.http.Status.unauthorized, ctx.response_status);
}

test "api key auth allows empty key list (no auth required)" {
    configure(&.{});
    var ctx = Context.initTest(.GET, "/v1/models", std.testing.allocator);
    defer ctx.deinit();
    const final = struct {
        fn h(c: *Context) anyerror!void {
            try c.text(.ok, "ok");
        }
    }.h;
    try middleware(&ctx, final);
    try std.testing.expectEqual(std.http.Status.ok, ctx.response_status);
}
