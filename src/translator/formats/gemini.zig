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
pub fn toOpenAI(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    const parsed = try std.json.parseFromSlice(GenerateContentRequest, allocator, raw_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const req = parsed.value;

    var messages: std.ArrayList(openai.Message) = .empty;
    defer messages.deinit(allocator);

    if (req.systemInstruction) |si| {
        for (si.parts) |part| {
            if (part.text) |t| {
                try messages.append(allocator, .{ .role = "system", .content = t });
            }
        }
    }

    for (req.contents) |content| {
        const text = if (content.parts.len > 0) content.parts[0].text else null;
        const role: []const u8 = if (std.mem.eql(u8, content.role, "model")) "assistant" else "user";
        try messages.append(allocator, .{ .role = role, .content = text });
    }

    const openai_req = openai.ChatRequest{
        .model = model,
        .messages = try messages.toOwnedSlice(allocator),
        .temperature = if (req.generationConfig) |gc| gc.temperature else null,
        .max_tokens = if (req.generationConfig) |gc| gc.maxOutputTokens else null,
        .top_p = if (req.generationConfig) |gc| gc.topP else null,
    };

    return try std.json.Stringify.valueAlloc(allocator, openai_req, .{ .emit_null_optional_fields = false });
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
