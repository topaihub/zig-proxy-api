const std = @import("std");
const gemini = @import("gemini.zig");

pub const Message = struct {
    role: []const u8 = "",
    content: ?[]const u8 = null,
};

pub const Choice = struct {
    index: u32 = 0,
    message: Message = .{},
    finish_reason: ?[]const u8 = null,
};

pub const ChatRequest = struct {
    model: []const u8 = "",
    messages: []const Message = &.{},
    stream: bool = false,
    temperature: ?f64 = null,
    max_tokens: ?i64 = null,
    top_p: ?f64 = null,
};

pub const ChatResponse = struct {
    id: []const u8 = "",
    object: []const u8 = "chat.completion",
    model: []const u8 = "",
    choices: []const Choice = &.{},
};

/// Convert an OpenAI ChatRequest to a Gemini GenerateContentRequest JSON blob.
/// Caller owns the returned slice and must free it with the provided allocator.
pub fn toGemini(allocator: std.mem.Allocator, raw_json: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(ChatRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var system_parts: std.ArrayList(gemini.Part) = .empty;
    var contents: std.ArrayList(gemini.Content) = .empty;

    for (req.messages) |msg| {
        if (std.mem.eql(u8, msg.role, "system")) {
            try system_parts.append(arena, .{ .text = msg.content });
        } else {
            const role: []const u8 = if (std.mem.eql(u8, msg.role, "assistant")) "model" else "user";
            const parts = try arena.alloc(gemini.Part, 1);
            parts[0] = .{ .text = msg.content };
            try contents.append(arena, .{ .role = role, .parts = parts });
        }
    }

    var gen_config: ?gemini.GenerationConfig = null;
    if (req.temperature != null or req.max_tokens != null or req.top_p != null) {
        gen_config = .{
            .temperature = req.temperature,
            .maxOutputTokens = req.max_tokens,
            .topP = req.top_p,
        };
    }

    const gemini_req = gemini.GenerateContentRequest{
        .contents = contents.items,
        .generationConfig = gen_config,
        .systemInstruction = if (system_parts.items.len > 0) .{ .role = "user", .parts = system_parts.items } else null,
    };

    // Serialize using the caller's allocator so the result outlives the arena
    return try std.json.Stringify.valueAlloc(allocator, gemini_req, .{ .emit_null_optional_fields = false });
}

/// Escape a string for safe inclusion in a JSON string value.
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

/// Convert a Gemini generateContent response to OpenAI chat completion response.
pub fn fromGeminiResponse(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(gemini.GenerateContentResponse, arena, raw_json, .{ .ignore_unknown_fields = true });
    const resp = parsed.value;

    var text: []const u8 = "";
    var finish: []const u8 = "stop";
    if (resp.candidates.len > 0) {
        const c = resp.candidates[0];
        if (c.content.parts.len > 0) {
            if (c.content.parts[0].text) |t| text = t;
        }
        if (c.finishReason) |fr| {
            finish = if (std.mem.eql(u8, fr, "STOP")) "stop" else fr;
        }
    }

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"id\":\"chatcmpl-gemini\",\"object\":\"chat.completion\",\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"");
    try jsonEscape(w, text);
    try w.writeAll("\"},\"finish_reason\":\"");
    try jsonEscape(w, finish);
    try w.writeAll("\"}]}");
    return try allocator.dupe(u8, buf.items);
}

/// Convert a Claude messages response to OpenAI chat completion response.
pub fn fromClaudeResponse(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    const claude = @import("claude.zig");
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(claude.MessagesResponse, arena, raw_json, .{ .ignore_unknown_fields = true });
    const resp = parsed.value;

    var text: []const u8 = "";
    if (resp.content.len > 0) {
        if (resp.content[0].text) |t| text = t;
    }
    const finish: []const u8 = if (resp.stop_reason) |sr|
        (if (std.mem.eql(u8, sr, "end_turn")) "stop" else sr)
    else
        "stop";

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"id\":\"");
    try jsonEscape(w, resp.id);
    try w.writeAll("\",\"object\":\"chat.completion\",\"model\":\"");
    try jsonEscape(w, model);
    try w.writeAll("\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"");
    try jsonEscape(w, text);
    try w.writeAll("\"},\"finish_reason\":\"");
    try jsonEscape(w, finish);
    try w.writeAll("\"}]}");
    return try allocator.dupe(u8, buf.items);
}

test "openai fromGeminiResponse converts correctly" {
    const gemini_resp = "{\"candidates\":[{\"content\":{\"role\":\"model\",\"parts\":[{\"text\":\"Hello!\"}]},\"finishReason\":\"STOP\"}]}";
    const result = try fromGeminiResponse(std.testing.allocator, gemini_resp, "gemini-2.5-pro");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello!") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "chat.completion") != null);
}

test "openai fromClaudeResponse converts correctly" {
    const claude_resp = "{\"id\":\"msg_01\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-sonnet-4\",\"content\":[{\"type\":\"text\",\"text\":\"Hello!\"}],\"stop_reason\":\"end_turn\"}";
    const result = try fromClaudeResponse(std.testing.allocator, claude_resp, "claude-sonnet-4");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello!") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "chat.completion") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "msg_01") != null);
}

test "parse openai chat request" {
    const json = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}],\"stream\":true}";
    const parsed = try std.json.parseFromSlice(ChatRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("gpt-4", parsed.value.model);
    try std.testing.expectEqual(true, parsed.value.stream);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.messages.len);
}

test "openai to gemini conversion" {
    const json = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}],\"temperature\":0.7,\"max_tokens\":1000}";
    const result = try toGemini(std.testing.allocator, json);
    defer std.testing.allocator.free(result);

    const parsed = try std.json.parseFromSlice(gemini.GenerateContentRequest, std.testing.allocator, result, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.contents.len);
    try std.testing.expectEqualStrings("hello", parsed.value.contents[0].parts[0].text.?);
    try std.testing.expectEqual(@as(f64, 0.7), parsed.value.generationConfig.?.temperature.?);
    try std.testing.expectEqual(@as(i64, 1000), parsed.value.generationConfig.?.maxOutputTokens.?);
}

test "openai system message becomes gemini systemInstruction" {
    const json = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"system\",\"content\":\"be helpful\"},{\"role\":\"user\",\"content\":\"hi\"}]}";
    const result = try toGemini(std.testing.allocator, json);
    defer std.testing.allocator.free(result);

    const parsed = try std.json.parseFromSlice(gemini.GenerateContentRequest, std.testing.allocator, result, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.contents.len);
    try std.testing.expectEqualStrings("be helpful", parsed.value.systemInstruction.?.parts[0].text.?);
}
