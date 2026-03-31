const std = @import("std");
const framework = @import("framework");

pub const server = @import("server/root.zig");
pub const config = @import("config/root.zig");
pub const auth = @import("auth/root.zig");
pub const translator = @import("translator/root.zig");
pub const executor = @import("executor/root.zig");
pub const scheduler = @import("scheduler/root.zig");
pub const store = @import("store/root.zig");
pub const management = @import("management/root.zig");
pub const tui = @import("tui/root.zig");
pub const api = @import("api/root.zig");
pub const logging = @import("logging/root.zig");
pub const wsrelay = @import("wsrelay/root.zig");
pub const amp = @import("amp/root.zig");

fn rootHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{ .message = "CLI Proxy API Server (Zig)", .version = "0.1.0" });
}

fn modelsHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{ .object = "list", .data = &[_]struct { id: []const u8, object: []const u8 }{
        .{ .id = "gemini-2.5-pro", .object = "model" },
        .{ .id = "claude-sonnet-4", .object = "model" },
    } });
}

fn chatCompletionsHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.chatCompletions(ctx);
    try ctx.json(.ok, .{ .object = "chat.completion", .model = "stub" });
}

fn messagesHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.claudeMessages(ctx);
    try ctx.json(.ok, .{ .type = "message", .model = "stub" });
}

fn completionsHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.completions(ctx);
    try ctx.json(.ok, .{ .object = "text_completion", .model = "stub" });
}

fn countTokensHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.countTokens(ctx);
    try ctx.json(.ok, .{ .input_tokens = 0 });
}

fn responsesHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.responses(ctx);
    try ctx.json(.ok, .{ .@"type" = "response", .model = "stub" });
}

fn responsesCompactHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.responsesCompact(ctx);
    try ctx.json(.ok, .{ .@"type" = "response", .model = "stub" });
}

fn responsesWsHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.responsesWebsocket(ctx);
    try ctx.json(.ok, .{ .@"type" = "websocket", .status = "not_implemented" });
}

fn geminiModelsHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.geminiModels(ctx);
    try ctx.json(.ok, .{ .models = &[_]u8{} });
}

fn geminiGenerateHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.geminiGenerate(ctx);
    try ctx.json(.ok, .{ .candidates = &[_]u8{} });
}

fn geminiGetModelHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.geminiGetModel(ctx);
    try ctx.json(.ok, .{ .name = "stub" });
}

fn geminiCliHandler(ctx: *server.Context) anyerror!void {
    if (global_api_handlers) |*h| return h.geminiCliHandler(ctx);
    try ctx.json(.ok, .{ .@"type" = "gemini-cli" });
}

fn managementPanelHandler(ctx: *server.Context) anyerror!void {
    ctx.setHeader("Content-Type", "text/html");
    try ctx.raw(.ok,
        \\<!DOCTYPE html><html><head><title>Management Panel</title></head><body>
        \\<h1>Management Panel</h1>
        \\<ul>
        \\<li><a href="/v1/models">Models</a></li>
        \\<li><a href="/v1beta/models">Gemini Models</a></li>
        \\</ul>
        \\</body></html>
    );
}

var global_api_handlers: ?api.ApiHandlers = null;

const CliArgs = struct {
    config_path: []const u8 = "config.json",
    port_override: ?u16 = null,
};

fn parseArgs(allocator: std.mem.Allocator) CliArgs {
    var result = CliArgs{};
    var args = std.process.args();
    _ = args.skip(); // skip executable name
    _ = allocator;
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--config=")) {
            result.config_path = arg["--config=".len..];
        } else if (std.mem.startsWith(u8, arg, "--port=")) {
            result.port_override = std.fmt.parseInt(u16, arg["--port=".len..], 10) catch null;
        }
    }
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Parse CLI args
    const cli = parseArgs(allocator);

    // 2. Load config
    var loaded = config.loadFromFile(cli.config_path, allocator) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (loaded) |*l| l.deinit();
    const cfg = if (loaded) |l| l.config else config.Config{};

    const port: u16 = cli.port_override orelse cfg.port;
    const host = if (cfg.host.len > 0) cfg.host else "127.0.0.1";

    // 3. Init framework AppContext
    var app_ctx = try framework.AppContext.init(allocator, .{});
    defer app_ctx.deinit();

    // 4. Init auth Manager + FileStore
    var file_store = auth.FileStore.init(allocator, cfg.auth_dir);
    defer file_store.deinit();
    var auth_mgr = auth.Manager.init(allocator);
    defer auth_mgr.deinit();
    auth_mgr.setStore(file_store.store());

    // 5. Init scheduler Selector
    const strategy: scheduler.Strategy = if (std.mem.eql(u8, cfg.routing.strategy, "fill-first")) .fill_first else .round_robin;
    var sel = scheduler.Selector.init(strategy);
    _ = &sel;

    // 6. Init translator Registry
    var trans_reg = translator.Registry.init(allocator);
    defer trans_reg.deinit();
    translator.registerAll(&trans_reg);

    // 7. Init executor ExecutorRegistry
    var exec_reg = executor.ExecutorRegistry.init(allocator);
    defer exec_reg.deinit();

    // 7b. Init API handlers
    global_api_handlers = api.ApiHandlers.init(allocator, &trans_reg, &exec_reg);

    // 8. Init ManagementHandler, register routes if secret key configured
    var mgmt = management.ManagementHandler.init(allocator);
    defer mgmt.deinit();

    // 9. Set up HttpServer
    var srv = server.HttpServer.init(allocator, .{
        .host = host,
        .port = port,
        .app_context = &app_ctx,
    });
    defer srv.deinit();

    // 10. Add middleware
    srv.use(server.middleware.cors);
    srv.use(server.middleware.recovery);
    if (cfg.api_keys.len > 0) {
        auth.api_key.configure(cfg.api_keys);
        srv.use(auth.api_key.middleware);
    }

    // 8b. Register management routes if secret key configured
    if (cfg.remote_management.secret_key.len > 0) {
        mgmt.setSecretKey(cfg.remote_management.secret_key);
        try mgmt.registerRoutes(&srv.router);
    }

    // 11. Register API routes
    srv.router.get("/", rootHandler);
    srv.router.get("/v1/models", modelsHandler);
    srv.router.post("/v1/chat/completions", chatCompletionsHandler);
    srv.router.post("/v1/messages", messagesHandler);

    // OpenAI compatible
    srv.router.post("/v1/completions", completionsHandler);
    srv.router.post("/v1/messages/count_tokens", countTokensHandler);
    srv.router.get("/v1/responses", responsesWsHandler);
    srv.router.post("/v1/responses", responsesHandler);
    srv.router.post("/v1/responses/compact", responsesCompactHandler);

    // Gemini compatible
    srv.router.get("/v1beta/models", geminiModelsHandler);
    srv.router.post("/v1beta/models/*action", geminiGenerateHandler);
    srv.router.get("/v1beta/models/*action", geminiGetModelHandler);

    // Gemini CLI internal
    srv.router.post("/v1internal:method", geminiCliHandler);

    // Management panel
    srv.router.get("/management.html", managementPanelHandler);

    // 12. Signal handling
    // NOTE: Skipped — std.posix.sigaction setup is complex on Zig 0.15.x;
    // graceful shutdown can be added via srv.shutdown() when signal infra stabilizes.

    // 13. Log startup info and serve
    var log = app_ctx.logger.subsystem("server");
    log.info("server starting", &.{
        framework.LogField.string("host", host),
        framework.LogField.int("port", @intCast(port)),
        framework.LogField.string("routing", strategy.name()),
    });

    try srv.listenAndServe();
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}

test {
    std.testing.refAllDecls(@This());
}
