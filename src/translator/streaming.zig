const std = @import("std");
const Format = @import("types.zig").Format;

pub const SseChunk = struct {
    event: ?[]const u8 = null,
    data: ?[]const u8 = null,
    is_done: bool = false,
};

pub fn parseSseChunk(raw: []const u8) SseChunk {
    const trimmed = std.mem.trim(u8, raw, "\r\n ");
    if (trimmed.len == 0) return .{};
    if (std.mem.indexOf(u8, trimmed, "[DONE]") != null) return .{ .is_done = true };
    if (std.mem.startsWith(u8, trimmed, "data: ")) return .{ .data = trimmed[6..] };
    if (std.mem.startsWith(u8, trimmed, "data:")) return .{ .data = trimmed[5..] };
    return .{};
}

pub const StreamTranslator = struct {
    allocator: std.mem.Allocator,
    source_format: Format,
    target_format: Format,
    model: []const u8,
    chunk_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, source: Format, target: Format, model: []const u8) StreamTranslator {
        return .{ .allocator = allocator, .source_format = source, .target_format = target, .model = model };
    }

    pub fn translateChunk(self: *StreamTranslator, raw_chunk: []const u8) !?[]u8 {
        const chunk = parseSseChunk(raw_chunk);
        if (chunk.is_done) return try self.allocator.dupe(u8, "data: [DONE]\n\n");
        const data = chunk.data orelse return null;

        self.chunk_count += 1;

        if (self.source_format == self.target_format) {
            return try std.fmt.allocPrint(self.allocator, "data: {s}\n\n", .{data});
        }

        const text = extractTextFromChunk(data, self.source_format);
        if (text == null) return try std.fmt.allocPrint(self.allocator, "data: {s}\n\n", .{data});

        const translated = try buildStreamChunk(self.allocator, text.?, self.target_format, self.model, self.chunk_count);
        defer self.allocator.free(translated);
        return try std.fmt.allocPrint(self.allocator, "data: {s}\n\n", .{translated});
    }

    pub fn deinit(self: *StreamTranslator) void {
        _ = self;
    }
};

fn extractTextFromChunk(json: []const u8, format: Format) ?[]const u8 {
    return switch (format) {
        .openai, .openai_response, .codex => findJsonStringValue(json, "content"),
        .gemini, .gemini_cli, .antigravity => findJsonStringValue(json, "text"),
        .claude => findJsonStringValue(json, "text"),
    };
}

fn findJsonStringValue(json: []const u8, key: []const u8) ?[]const u8 {
    var search_buf: [64]u8 = undefined;
    const pattern = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const start = (std.mem.indexOf(u8, json, pattern) orelse return null) + pattern.len;
    var i = start;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\') {
            i += 1;
            continue;
        }
        if (json[i] == '"') return json[start..i];
    }
    return null;
}

fn buildStreamChunk(allocator: std.mem.Allocator, text: []const u8, format: Format, model: []const u8, index: usize) ![]u8 {
    return switch (format) {
        .openai, .openai_response, .codex => try std.fmt.allocPrint(allocator,
            "{{\"id\":\"chatcmpl-stream\",\"object\":\"chat.completion.chunk\",\"model\":\"{s}\",\"choices\":[{{\"index\":0,\"delta\":{{\"content\":\"{s}\"}},\"finish_reason\":null}}]}}",
            .{ model, text },
        ),
        .gemini, .gemini_cli, .antigravity => try std.fmt.allocPrint(allocator,
            "{{\"candidates\":[{{\"content\":{{\"role\":\"model\",\"parts\":[{{\"text\":\"{s}\"}}]}},\"index\":{d}}}]}}",
            .{ text, index },
        ),
        .claude => try std.fmt.allocPrint(allocator,
            "{{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{{\"type\":\"text_delta\",\"text\":\"{s}\"}}}}",
            .{text},
        ),
    };
}

test "parse sse chunk extracts data" {
    const chunk = parseSseChunk("data: {\"text\":\"hello\"}\n\n");
    try std.testing.expect(chunk.data != null);
    try std.testing.expect(!chunk.is_done);
}

test "parse sse done" {
    const chunk = parseSseChunk("data: [DONE]\n\n");
    try std.testing.expect(chunk.is_done);
}

test "stream translator passthrough same format" {
    var st = StreamTranslator.init(std.testing.allocator, .openai, .openai, "gpt-4");
    defer st.deinit();
    const result = try st.translateChunk("data: {\"test\":true}\n\n");
    try std.testing.expect(result != null);
    defer std.testing.allocator.free(result.?);
    try std.testing.expect(std.mem.indexOf(u8, result.?, "test") != null);
}

test "stream translator cross-format" {
    var st = StreamTranslator.init(std.testing.allocator, .openai, .gemini, "gemini-pro");
    defer st.deinit();
    const result = try st.translateChunk("data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\n");
    try std.testing.expect(result != null);
    defer std.testing.allocator.free(result.?);
    try std.testing.expect(std.mem.indexOf(u8, result.?, "hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.?, "candidates") != null);
}
