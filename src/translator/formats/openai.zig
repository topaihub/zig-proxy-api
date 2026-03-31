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
pub fn toGemini(allocator: std.mem.Allocator, raw_json: []const u8) ![]u8 {
    const parsed = try std.json.parseFromSlice(ChatRequest, allocator, raw_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const req = parsed.value;

    var system_parts: std.ArrayList(gemini.Part) = .empty;
    defer system_parts.deinit(allocator);
    var contents: std.ArrayList(gemini.Content) = .empty;
    defer contents.deinit(allocator);

    for (req.messages) |msg| {
        if (std.mem.eql(u8, msg.role, "system")) {
            try system_parts.append(allocator, .{ .text = msg.content });
        } else {
            const role: []const u8 = if (std.mem.eql(u8, msg.role, "assistant")) "model" else "user";
            const parts = try allocator.alloc(gemini.Part, 1);
            parts[0] = .{ .text = msg.content };
            try contents.append(allocator, .{ .role = role, .parts = parts });
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
        .contents = try contents.toOwnedSlice(allocator),
        .generationConfig = gen_config,
        .systemInstruction = if (system_parts.items.len > 0) .{ .role = "user", .parts = try system_parts.toOwnedSlice(allocator) } else null,
    };

    return try std.json.Stringify.valueAlloc(allocator, gemini_req, .{ .emit_null_optional_fields = false });
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
