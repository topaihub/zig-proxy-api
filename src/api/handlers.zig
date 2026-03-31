const std = @import("std");
const server = @import("../server/root.zig");
const translator = @import("../translator/root.zig");
const executor = @import("../executor/root.zig");

pub const ApiHandlers = struct {
    allocator: std.mem.Allocator,
    translator_registry: *translator.Registry,
    executor_registry: *executor.ExecutorRegistry,

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

    /// POST /v1/gemini/generateContent — Gemini-compatible endpoint
    pub fn geminiGenerate(self: *ApiHandlers, ctx: *server.Context) !void {
        try self.handleRequest(ctx, .gemini, "gemini");
    }

    fn handleRequest(
        self: *ApiHandlers,
        ctx: *server.Context,
        source_format: translator.Format,
        default_provider: []const u8,
    ) !void {
        const body = ctx.readBody() orelse {
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

        const resp = try exec.execute(self.allocator, .{
            .model = model,
            .payload = translated,
            .format = target_format,
        }, .{
            .source_format = source_format,
            .original_request = body,
        });

        if (stream) {
            try writeAsSSE(ctx, resp.payload);
        } else {
            try ctx.raw(@enumFromInt(resp.status_code), resp.payload);
        }
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
