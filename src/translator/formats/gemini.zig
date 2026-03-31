const std = @import("std");
const openai = @import("openai.zig");

pub const Part = struct {
    text: ?[]const u8 = null,
};

pub const Content = struct {
    role: []const u8 = "",
    parts: []const Part = &.{},
};

pub const GenerationConfig = struct {
    temperature: ?f64 = null,
    maxOutputTokens: ?i64 = null,
    topP: ?f64 = null,
    topK: ?i64 = null,
};

pub const GenerateContentRequest = struct {
    contents: []const Content = &.{},
    generationConfig: ?GenerationConfig = null,
    systemInstruction: ?Content = null,
};

pub const Candidate = struct {
    content: Content = .{},
    finishReason: ?[]const u8 = null,
};

pub const GenerateContentResponse = struct {
    candidates: []const Candidate = &.{},
};

/// Convert a Gemini GenerateContentRequest to an OpenAI ChatRequest JSON blob.
/// Caller owns the returned slice and must free it with the provided allocator.
pub fn toOpenAI(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(GenerateContentRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var messages: std.ArrayList(openai.Message) = .empty;

    if (req.systemInstruction) |si| {
        for (si.parts) |part| {
            if (part.text) |t| {
                try messages.append(arena, .{ .role = "system", .content = t });
            }
        }
    }

    for (req.contents) |content| {
        const text = if (content.parts.len > 0) content.parts[0].text else null;
        const role: []const u8 = if (std.mem.eql(u8, content.role, "model")) "assistant" else "user";
        try messages.append(arena, .{ .role = role, .content = text });
    }

    const openai_req = openai.ChatRequest{
        .model = model,
        .messages = messages.items,
        .temperature = if (req.generationConfig) |gc| gc.temperature else null,
        .max_tokens = if (req.generationConfig) |gc| gc.maxOutputTokens else null,
        .top_p = if (req.generationConfig) |gc| gc.topP else null,
    };

    return try std.json.Stringify.valueAlloc(allocator, openai_req, .{ .emit_null_optional_fields = false });
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

/// Convert an OpenAI chat completion response to Gemini generateContent response.
pub fn fromOpenAIResponse(allocator: std.mem.Allocator, raw_json: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(openai.ChatResponse, arena, raw_json, .{ .ignore_unknown_fields = true });
    const resp = parsed.value;

    var text: []const u8 = "";
    var finish: []const u8 = "STOP";
    if (resp.choices.len > 0) {
        if (resp.choices[0].message.content) |c| text = c;
        if (resp.choices[0].finish_reason) |fr| {
            finish = if (std.mem.eql(u8, fr, "stop")) "STOP" else fr;
        }
    }

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"candidates\":[{\"content\":{\"role\":\"model\",\"parts\":[{\"text\":\"");
    try jsonEscape(w, text);
    try w.writeAll("\"}]},\"finishReason\":\"");
    try jsonEscape(w, finish);
    try w.writeAll("\"}]}");
    return try allocator.dupe(u8, buf.items);
}

test "gemini fromOpenAIResponse converts correctly" {
    const openai_resp = "{\"id\":\"chatcmpl-1\",\"object\":\"chat.completion\",\"model\":\"gpt-4\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"Hello!\"},\"finish_reason\":\"stop\"}]}";
    const result = try fromOpenAIResponse(std.testing.allocator, openai_resp);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello!") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "STOP") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "model") != null);
}

test "parse gemini request" {
    const json = "{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"hello\"}]}]}";
    const parsed = try std.json.parseFromSlice(GenerateContentRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.contents.len);
    try std.testing.expectEqualStrings("hello", parsed.value.contents[0].parts[0].text.?);
}

test "gemini to openai conversion" {
    const json = "{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"hello\"}]}],\"generationConfig\":{\"temperature\":0.5,\"maxOutputTokens\":500}}";
    const result = try toOpenAI(std.testing.allocator, json, "gpt-4");
    defer std.testing.allocator.free(result);

    const parsed = try std.json.parseFromSlice(openai.ChatRequest, std.testing.allocator, result, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("gpt-4", parsed.value.model);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.messages.len);
    try std.testing.expectEqualStrings("hello", parsed.value.messages[0].content.?);
    try std.testing.expectEqual(@as(f64, 0.5), parsed.value.temperature.?);
    try std.testing.expectEqual(@as(i64, 500), parsed.value.max_tokens.?);
}

test "gemini systemInstruction becomes openai system message" {
    const json = "{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"hi\"}]}],\"systemInstruction\":{\"role\":\"user\",\"parts\":[{\"text\":\"be helpful\"}]}}";
    const result = try toOpenAI(std.testing.allocator, json, "gpt-4");
    defer std.testing.allocator.free(result);

    const parsed = try std.json.parseFromSlice(openai.ChatRequest, std.testing.allocator, result, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.value.messages.len);
    try std.testing.expectEqualStrings("system", parsed.value.messages[0].role);
    try std.testing.expectEqualStrings("be helpful", parsed.value.messages[0].content.?);
}
