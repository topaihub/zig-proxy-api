const std = @import("std");
const openai = @import("openai.zig");
const gemini = @import("gemini.zig");
const claude = @import("claude.zig");

pub const ResponsesRequest = struct {
    model: []const u8 = "",
    input: ?[]const u8 = null,
    instructions: ?[]const u8 = null,
    stream: bool = false,
    temperature: ?f64 = null,
    max_output_tokens: ?i64 = null,
};

pub const ResponsesResponse = struct {
    id: []const u8 = "",
    object: []const u8 = "response",
    model: []const u8 = "",
    output: []const OutputItem = &.{},
    status: []const u8 = "completed",
};

pub const OutputItem = struct {
    type: []const u8 = "message",
    role: []const u8 = "assistant",
    content: []const ContentPart = &.{},
};

pub const ContentPart = struct {
    type: []const u8 = "output_text",
    text: ?[]const u8 = null,
};

fn jsonEscape(w: anytype, s: []const u8) !void {
    for (s) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        else => try w.writeByte(c),
    };
}

/// Convert OpenAI chat request to Codex Responses API request.
pub fn fromOpenAI(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(openai.ChatRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\"");

    // Collect system -> instructions, user messages -> input
    var instructions: ?[]const u8 = null;
    var input_parts: std.ArrayListUnmanaged([]const u8) = .{};
    defer input_parts.deinit(allocator);
    for (req.messages) |msg| {
        if (std.mem.eql(u8, msg.role, "system")) {
            instructions = msg.content;
        } else if (msg.content) |c| {
            try input_parts.append(allocator, c);
        }
    }

    if (instructions) |inst| {
        try w.writeAll(",\"instructions\":\"");
        try jsonEscape(w, inst);
        try w.writeAll("\"");
    }

    if (input_parts.items.len > 0) {
        try w.writeAll(",\"input\":\"");
        for (input_parts.items, 0..) |part, i| {
            if (i > 0) try w.writeAll("\\n");
            try jsonEscape(w, part);
        }
        try w.writeAll("\"");
    }

    if (req.max_tokens) |mt| try w.print(",\"max_output_tokens\":{d}", .{mt});
    if (req.temperature) |t| try w.print(",\"temperature\":{d}", .{t});
    if (req.stream) try w.writeAll(",\"stream\":true");

    try w.writeAll("}");
    return try allocator.dupe(u8, buf.items);
}

/// Convert Codex Responses API response to OpenAI chat completion.
pub fn toOpenAI(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(ResponsesResponse, arena, raw_json, .{ .ignore_unknown_fields = true });
    const resp = parsed.value;

    var text: []const u8 = "";
    if (resp.output.len > 0 and resp.output[0].content.len > 0) {
        if (resp.output[0].content[0].text) |t| text = t;
    }

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"id\":\"");
    try jsonEscape(w, resp.id);
    try w.writeAll("\",\"object\":\"chat.completion\",\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"");
    try jsonEscape(w, text);
    try w.writeAll("\"},\"finish_reason\":\"stop\"}]}");
    return try allocator.dupe(u8, buf.items);
}

/// Convert Gemini request to Codex request.
pub fn fromGemini(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(gemini.GenerateContentRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\"");

    // systemInstruction -> instructions
    if (req.systemInstruction) |si| {
        if (si.parts.len > 0) {
            if (si.parts[0].text) |t| {
                try w.writeAll(",\"instructions\":\"");
                try jsonEscape(w, t);
                try w.writeAll("\"");
            }
        }
    }

    // contents -> input (concatenate user text parts)
    if (req.contents.len > 0) {
        try w.writeAll(",\"input\":\"");
        var first = true;
        for (req.contents) |content| {
            for (content.parts) |part| {
                if (part.text) |t| {
                    if (!first) try w.writeAll("\\n");
                    first = false;
                    try jsonEscape(w, t);
                }
            }
        }
        try w.writeAll("\"");
    }

    if (req.generationConfig) |gc| {
        if (gc.maxOutputTokens) |mt| try w.print(",\"max_output_tokens\":{d}", .{mt});
        if (gc.temperature) |t| try w.print(",\"temperature\":{d}", .{t});
    }

    try w.writeAll("}");
    return try allocator.dupe(u8, buf.items);
}

/// Convert Claude request to Codex request.
pub fn fromClaude(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(claude.MessagesRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\"");

    if (req.system) |s| {
        try w.writeAll(",\"instructions\":\"");
        try jsonEscape(w, s);
        try w.writeAll("\"");
    }

    if (req.messages.len > 0) {
        try w.writeAll(",\"input\":\"");
        var first = true;
        for (req.messages) |msg| {
            if (msg.content) |c| {
                if (!first) try w.writeAll("\\n");
                first = false;
                try jsonEscape(w, c);
            }
        }
        try w.writeAll("\"");
    }

    if (req.max_tokens) |mt| try w.print(",\"max_output_tokens\":{d}", .{mt});
    if (req.temperature) |t| try w.print(",\"temperature\":{d}", .{t});
    if (req.stream) try w.writeAll(",\"stream\":true");

    try w.writeAll("}");
    return try allocator.dupe(u8, buf.items);
}

test "codex fromOpenAI converts request" {
    const input = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"system\",\"content\":\"Be helpful\"},{\"role\":\"user\",\"content\":\"hello\"}],\"max_tokens\":100}";
    const result = try fromOpenAI(std.testing.allocator, input, "codex-mini");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "codex-mini") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Be helpful") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "max_output_tokens") != null);
}

test "codex toOpenAI converts response" {
    const input = "{\"id\":\"resp_01\",\"object\":\"response\",\"model\":\"codex-mini\",\"output\":[{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hi there!\"}]}],\"status\":\"completed\"}";
    const result = try toOpenAI(std.testing.allocator, input, "codex-mini");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hi there!") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "chat.completion") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "resp_01") != null);
}

test "codex fromGemini converts request" {
    const input = "{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"hello\"}]}],\"systemInstruction\":{\"role\":\"user\",\"parts\":[{\"text\":\"Be helpful\"}]},\"generationConfig\":{\"maxOutputTokens\":500}}";
    const result = try fromGemini(std.testing.allocator, input, "codex-mini");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Be helpful") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "max_output_tokens") != null);
}

test "codex fromClaude converts request" {
    const input = "{\"model\":\"claude-sonnet-4\",\"max_tokens\":1024,\"system\":\"Be helpful\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}";
    const result = try fromClaude(std.testing.allocator, input, "codex-mini");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Be helpful") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "codex-mini") != null);
}

test "parse codex responses request" {
    const json = "{\"model\":\"gpt-5-codex\",\"input\":\"hello\",\"stream\":true}";
    const parsed = try std.json.parseFromSlice(ResponsesRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("gpt-5-codex", parsed.value.model);
    try std.testing.expectEqual(true, parsed.value.stream);
}
