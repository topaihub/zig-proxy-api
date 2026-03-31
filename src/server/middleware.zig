const std = @import("std");
const ctx = @import("context.zig");
const Context = ctx.Context;
const Handler = ctx.Handler;

pub const Middleware = *const fn (*Context, Handler) anyerror!void;

const max_middlewares = 32;

var stored_middlewares: [max_middlewares]Middleware = undefined;
var stored_final: Handler = undefined;
var stored_len: usize = 0;

fn makeStep(comptime i: usize) Handler {
    return &struct {
        fn handler(c: *Context) anyerror!void {
            if (i < max_middlewares and i < stored_len) {
                return stored_middlewares[i](c, makeStep(if (i + 1 < max_middlewares) i + 1 else i));
            } else {
                return stored_final(c);
            }
        }
    }.handler;
}

pub fn buildChain(middlewares: []const Middleware, final: Handler) Handler {
    stored_len = @min(middlewares.len, max_middlewares);
    for (0..stored_len) |i| {
        stored_middlewares[i] = middlewares[i];
    }
    stored_final = final;
    return makeStep(0);
}

// Built-in middleware

pub fn cors(c: *Context, next: Handler) anyerror!void {
    c.setHeader("Access-Control-Allow-Origin", "*");
    c.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    c.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (c.method() == .OPTIONS) {
        c.setStatus(.no_content);
        return;
    }
    return next(c);
}

var request_counter: u64 = 0;

pub fn requestId(c: *Context, next: Handler) anyerror!void {
    request_counter += 1;
    var buf: [20]u8 = undefined;
    const len = std.fmt.formatIntBuf(&buf, request_counter, 10, .lower, .{});
    c.setHeader("X-Request-Id", buf[0..len]);
    return next(c);
}

pub fn recovery(c: *Context, next: Handler) anyerror!void {
    next(c) catch {
        c.json(.internal_server_error, .{ .@"error" = "Internal Server Error" }) catch {};
    };
}

// Tests

test "chain executes in order" {
    const alloc = std.testing.allocator;
    var c = Context.initTest(.GET, "/test", alloc);
    defer c.deinit();

    const m1 = struct {
        fn f(cx: *Context, next: Handler) anyerror!void {
            try cx.response_buf.appendSlice(cx.allocator, "m1>");
            return next(cx);
        }
    }.f;
    const m2 = struct {
        fn f(cx: *Context, next: Handler) anyerror!void {
            try cx.response_buf.appendSlice(cx.allocator, "m2>");
            return next(cx);
        }
    }.f;
    const final_handler = struct {
        fn f(cx: *Context) anyerror!void {
            try cx.response_buf.appendSlice(cx.allocator, "done");
        }
    }.f;

    const chain = buildChain(&.{ m1, m2 }, final_handler);
    try chain(&c);
    try std.testing.expectEqualStrings("m1>m2>done", c.testResponseBody());
}

test "middleware can short-circuit" {
    const alloc = std.testing.allocator;
    var c = Context.initTest(.GET, "/secret", alloc);
    defer c.deinit();

    const auth = struct {
        fn f(cx: *Context, _: Handler) anyerror!void {
            try cx.text(.forbidden, "denied");
        }
    }.f;
    const final_handler = struct {
        fn f(cx: *Context) anyerror!void {
            try cx.response_buf.appendSlice(cx.allocator, "should not reach");
        }
    }.f;

    const chain = buildChain(&.{auth}, final_handler);
    try chain(&c);
    try std.testing.expectEqualStrings("denied", c.testResponseBody());
    try std.testing.expectEqual(std.http.Status.forbidden, c.response_status);
}
