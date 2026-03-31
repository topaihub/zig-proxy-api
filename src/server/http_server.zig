const std = @import("std");
const framework = @import("framework");
const router_mod = @import("router.zig");
const context_mod = @import("context.zig");
const middleware_mod = @import("middleware.zig");

const Router = router_mod.Router;
const Context = context_mod.Context;
const Handler = context_mod.Handler;
const Middleware = middleware_mod.Middleware;

pub const ServerConfig = struct {
    host: []const u8 = "0.0.0.0",
    port: u16 = 8317,
    app_context: ?*framework.AppContext = null,
};

pub const HttpServer = struct {
    allocator: std.mem.Allocator,
    config: ServerConfig,
    router: Router,
    app_context: ?*framework.AppContext,
    global_middlewares: [16]Middleware = undefined,
    global_mw_count: u8 = 0,
    shutdown_requested: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) HttpServer {
        return .{
            .allocator = allocator,
            .config = config,
            .router = Router.init(allocator),
            .app_context = config.app_context,
            .shutdown_requested = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *HttpServer) void {
        self.router.deinit();
    }

    pub fn use(self: *HttpServer, mw: Middleware) void {
        if (self.global_mw_count < 16) {
            self.global_middlewares[self.global_mw_count] = mw;
            self.global_mw_count += 1;
        }
    }

    pub fn shutdown(self: *HttpServer) void {
        self.shutdown_requested.store(true, .release);
    }

    pub fn listenAndServe(self: *HttpServer) !void {
        const addr = try std.net.Address.parseIp(self.config.host, self.config.port);
        var listener = try addr.listen(.{ .reuse_address = true });
        defer listener.deinit();

        while (!self.shutdown_requested.load(.acquire)) {
            const conn = listener.accept() catch |err| switch (err) {
                error.ConnectionAborted => continue,
                else => return err,
            };
            defer conn.stream.close();
            self.handleConnection(conn.stream) catch continue;
        }
    }

    fn handleConnection(self: *HttpServer, stream: std.net.Stream) !void {
        var read_buf: [8192]u8 = undefined;
        var write_buf: [8192]u8 = undefined;
        var net_reader = stream.reader(&read_buf);
        var net_writer = stream.writer(&write_buf);
        var http_server = std.http.Server.init(net_reader.interface(), &net_writer.interface);
        var req = http_server.receiveHead() catch return;

        const target = req.head.target;
        const qi = std.mem.indexOfScalar(u8, target, '?');
        const path = if (qi) |q| target[0..q] else target;
        const query_string: ?[]const u8 = if (qi) |q| target[q + 1 ..] else null;

        // Begin request trace
        var trace: ?framework.RequestTrace = null;
        if (self.app_context) |app_ctx| {
            trace = framework.observability.request_trace.begin(
                self.allocator,
                app_ctx.logger,
                .http,
                "req",
                @tagName(req.head.method),
                path,
                query_string,
            ) catch null;
        }
        defer if (trace) |*t| t.deinit();

        if (self.router.resolve(req.head.method, path)) |match| {
            var ctx = Context.initTest(req.head.method, path, self.allocator);
            defer ctx.deinit();
            for (match.params[0..match.param_count]) |p| ctx.setParam(p.key, p.value);

            const final = match.handler;
            const mws = self.global_middlewares[0..self.global_mw_count];
            const handler = if (mws.len > 0) middleware_mod.buildChain(mws, final) else final;
            handler(&ctx) catch {};

            // Complete request trace
            if (trace) |*t| {
                if (self.app_context) |app_ctx| {
                    framework.observability.request_trace.complete(
                        app_ctx.logger,
                        t,
                        @intFromEnum(ctx.response_status),
                        null,
                    );
                }
            }

            const body = ctx.response_buf.items;
            var headers: [16]std.http.Header = undefined;
            for (ctx.response_headers[0..ctx.response_header_count], 0..) |h, i| {
                headers[i] = .{ .name = h.name, .value = h.value };
            }
            try req.respond(body, .{
                .status = ctx.response_status,
                .extra_headers = headers[0..ctx.response_header_count],
                .keep_alive = false,
            });
        } else {
            // Complete request trace for 404
            if (trace) |*t| {
                if (self.app_context) |app_ctx| {
                    framework.observability.request_trace.complete(app_ctx.logger, t, 404, null);
                }
            }
            try req.respond("{\"error\":\"Not Found\"}", .{
                .status = .not_found,
                .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                .keep_alive = false,
            });
        }
    }
};

test "http server initializes with config" {
    var app_ctx = try framework.AppContext.init(std.testing.allocator, .{ .console_log_enabled = false });
    defer app_ctx.deinit();
    var srv = HttpServer.init(std.testing.allocator, .{ .host = "127.0.0.1", .port = 0, .app_context = &app_ctx });
    defer srv.deinit();
    try std.testing.expectEqualStrings("127.0.0.1", srv.config.host);
}
