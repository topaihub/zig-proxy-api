const std = @import("std");
const framework = @import("framework");
const server = @import("../server/root.zig");
const translator = @import("../translator/root.zig");
const executor = @import("../executor/root.zig");

pub const ApiHandlers = struct {
    allocator: std.mem.Allocator,
    translator_registry: *translator.Registry,
    executor_registry: *executor.ExecutorRegistry,
    logger: ?*framework.Logger = null,

    pub fn init(
        allocator: std.mem.Allocator,
        tr: *translator.Registry,
        er: *executor.ExecutorRegistry,
    ) ApiHandlers {
        return .{
            .allocator = allocator,
            .translator_registry = tr,
            .executor_registry = er,
        };
    }

    pub fn setLogger(self: *ApiHandlers, logger: *framework.Logger) void {
        self.logger = logger;
    }

    /// POST /v1/chat/completions — OpenAI-compatible endpoint
    pub fn chatCompletions(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .openai, "openai");
    }

    fn isStreamRequest(body: []const u8) bool {
        return std.mem.indexOf(u8, body, "\"stream\":true") != null or
            std.mem.indexOf(u8, body, "\"stream\": true") != null;
    }

    fn writeAsSSE(ctx: *server.Context, data: []const u8) !void {
        ctx.setHeader("Content-Type", "text/event-stream");
        ctx.setHeader("Cache-Control", "no-cache");
        ctx.setHeader("Connection", "keep-alive");
        var buf = &ctx.response_buf;
        try buf.appendSlice(ctx.allocator, "data: ");
        try buf.appendSlice(ctx.allocator, data);
        try buf.appendSlice(ctx.allocator, "\n\ndata: [DONE]\n\n");
        ctx.response_status = .ok;
    }

    /// POST /v1/messages — Claude-compatible endpoint
    pub fn claudeMessages(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .claude, "claude");
    }

    /// POST /v1/completions — OpenAI completions endpoint
    pub fn completions(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .openai, "openai");
    }

    /// POST /v1/messages/count_tokens — Token counting stub
    pub fn countTokens(_: *ApiHandlers, ctx: *server.Context) !void {
        try ctx.json(.ok, .{ .input_tokens = 0 });
    }

    /// POST /v1/responses — Codex Responses API
    pub fn responses(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .codex, "openai");
    }

    /// POST /v1/responses/compact — Codex Responses API (compact)
    pub fn responsesCompact(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .codex, "openai");
    }

    /// GET /v1/responses — WebSocket upgrade stub
    pub fn responsesWebsocket(_: *ApiHandlers, ctx: *server.Context) !void {
        try ctx.json(.ok, .{ .@"type" = "websocket", .status = "not_implemented" });
    }

    /// GET /v1beta/models — Gemini model list
    pub fn geminiModels(_: *ApiHandlers, ctx: *server.Context) !void {
        try ctx.json(.ok, .{ .models = &[_]struct { name: []const u8, displayName: []const u8 }{
            .{ .name = "models/gemini-2.5-pro", .displayName = "Gemini 2.5 Pro" },
            .{ .name = "models/gemini-2.5-flash", .displayName = "Gemini 2.5 Flash" },
        } });
    }

    /// POST /v1beta/models/*action — Gemini generate
    pub fn geminiGenerate(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .gemini, "gemini");
    }

    /// GET /v1beta/models/*action — Gemini get model info
    pub fn geminiGetModel(_: *ApiHandlers, ctx: *server.Context) !void {
        const action = ctx.param("action") orelse "";
        // Extract model name before colon (e.g. "gemini-2.5-pro:generateContent" -> "gemini-2.5-pro")
        const colon = std.mem.indexOfScalar(u8, action, ':');
        const model_name = if (colon) |c| action[0..c] else action;
        try ctx.json(.ok, .{ .name = model_name, .displayName = model_name, .supportedGenerationMethods = &[_][]const u8{ "generateContent", "streamGenerateContent" } });
    }

    /// POST /v1internal:method — Gemini CLI internal endpoint
    pub fn geminiCliHandler(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .gemini_cli, "gemini");
    }

    fn handleRequest(
        self: *ApiHandlers,
        ctx: *server.Context,
        source_format: translator.Format,
        default_provider: []const u8,
    ) !void {
        // Method trace
        var method_trace: ?framework.MethodTrace = null;
        if (self.logger) |l| {
            method_trace = framework.MethodTrace.begin(self.allocator, l, "ApiHandler.handleRequest", default_provider, 5000) catch null;
        }
        defer if (method_trace) |*t| t.deinit();

        const body = ctx.readBody() orelse {
            if (method_trace) |*t| t.finishError("BadRequest", null, false);
            try ctx.text(.bad_request, "missing request body");
            return;
        };

        const stream = isStreamRequest(body);
        const model = extractModel(body) orelse "";
        const provider = providerFromModel(model) orelse default_provider;

        const exec = self.executor_registry.find(provider) orelse {
            if (stream) {
                try writeAsSSE(ctx, body);
            } else {
                try ctx.raw(.ok, body);
            }
            if (method_trace) |*t| t.finishSuccess("passthrough", false);
            return;
        };

        const target_format = formatFromProvider(provider);
        const translated = self.translator_registry.translateRequest(
            source_format,
            target_format,
            model,
            body,
            false,
        );

        // Step trace around executor call
        var step: ?framework.StepTrace = null;
        if (self.logger) |l| {
            step = framework.StepTrace.begin(self.allocator, l, "executor", provider, 5000) catch null;
        }
        defer if (step) |*s| s.deinit();

        const resp = exec.execute(self.allocator, .{
            .model = model,
            .payload = translated,
            .format = target_format,
        }, .{
            .source_format = source_format,
            .original_request = body,
        }) catch |err| {
            if (step) |*s| s.finish("EXECUTOR_ERROR");
            if (method_trace) |*t| t.finishError("ExecutorError", @errorName(err), false);
            return err;
        };

        if (step) |*s| s.finish(null);

        if (stream) {
            try writeAsSSE(ctx, resp.payload);
        } else {
            try ctx.raw(@enumFromInt(resp.status_code), resp.payload);
        }
        if (method_trace) |*t| t.finishSuccess("ok", false);
    }

    fn formatFromProvider(provider: []const u8) translator.Format {
        if (std.mem.eql(u8, provider, "gemini")) return .gemini;
        if (std.mem.eql(u8, provider, "claude")) return .claude;
        return .openai;
    }

    fn providerFromModel(model: []const u8) ?[]const u8 {
        if (model.len == 0) return null;
        if (std.mem.startsWith(u8, model, "gemini")) return "gemini";
        if (std.mem.startsWith(u8, model, "claude")) return "claude";
        if (std.mem.startsWith(u8, model, "gpt") or std.mem.startsWith(u8, model, "o1") or std.mem.startsWith(u8, model, "o3") or std.mem.startsWith(u8, model, "o4")) return "openai";
        return null;
    }

    fn extractModel(body: []const u8) ?[]const u8 {
        // Quick scan for "model":"<value>" without full JSON parse
        const needle = "\"model\":\"";
        const idx = std.mem.indexOf(u8, body, needle) orelse return null;
        const start = idx + needle.len;
        if (start >= body.len) return null;
        const end = std.mem.indexOfScalarPos(u8, body, start, '"') orelse return null;
        return body[start..end];
    }
};

test "api handlers init" {
    var tr = translator.Registry.init(std.testing.allocator);
    defer tr.deinit();
    var er = executor.ExecutorRegistry.init(std.testing.allocator);
    defer er.deinit();
    const h = ApiHandlers.init(std.testing.allocator, &tr, &er);
    _ = h;
}

test "extractModel parses model field" {
    const body = "{\"model\":\"gpt-4\",\"messages\":[]}";
    const model = ApiHandlers.extractModel(body);
    try std.testing.expectEqualStrings("gpt-4", model.?);
}

test "extractModel returns null for missing model" {
    const body = "{\"messages\":[]}";
    try std.testing.expect(ApiHandlers.extractModel(body) == null);
}

test "providerFromModel maps known prefixes" {
    try std.testing.expectEqualStrings("gemini", ApiHandlers.providerFromModel("gemini-2.5-pro").?);
    try std.testing.expectEqualStrings("claude", ApiHandlers.providerFromModel("claude-sonnet-4").?);
    try std.testing.expectEqualStrings("openai", ApiHandlers.providerFromModel("gpt-4").?);
    try std.testing.expect(ApiHandlers.providerFromModel("") == null);
}

test "isStreamRequest detects stream flag" {
    try std.testing.expect(ApiHandlers.isStreamRequest("{\"stream\":true,\"model\":\"gpt-4\"}"));
    try std.testing.expect(ApiHandlers.isStreamRequest("{\"stream\": true}"));
    try std.testing.expect(!ApiHandlers.isStreamRequest("{\"stream\":false}"));
    try std.testing.expect(!ApiHandlers.isStreamRequest("{\"model\":\"gpt-4\"}"));
}

test "writeAsSSE wraps data as SSE event" {
    var ctx = server.Context.initTest(.POST, "/v1/chat/completions", std.testing.allocator);
    defer ctx.deinit();
    try ApiHandlers.writeAsSSE(&ctx, "{\"choices\":[]}");
    const body = ctx.testResponseBody();
    try std.testing.expect(std.mem.startsWith(u8, body, "data: "));
    try std.testing.expect(std.mem.indexOf(u8, body, "data: [DONE]\n\n") != null);
    try std.testing.expectEqual(std.http.Status.ok, ctx.response_status);
}
