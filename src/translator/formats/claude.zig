const std = @import("std");

pub const MessagesRequest = struct {
    model: []const u8 = "",
    max_tokens: ?i64 = null,
    system: ?[]const u8 = null,
    messages: []const Message = &.{},
    stream: bool = false,
    temperature: ?f64 = null,
    top_p: ?f64 = null,
};

pub const Message = struct {
    role: []const u8 = "",
    content: ?[]const u8 = null,
};

pub const MessagesResponse = struct {
    id: []const u8 = "",
    type: []const u8 = "message",
    role: []const u8 = "assistant",
    model: []const u8 = "",
    content: []const ContentBlock = &.{},
    stop_reason: ?[]const u8 = null,
};

pub const ContentBlock = struct {
    type: []const u8 = "text",
    text: ?[]const u8 = null,
};

const openai = @import("openai.zig");

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

/// Convert OpenAI chat request to Claude messages request.
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

    if (req.max_tokens) |mt| {
        try w.print(",\"max_tokens\":{d}", .{mt});
    } else {
        try w.writeAll(",\"max_tokens\":4096");
    }

    // Extract system message and non-system messages
    var system_text: ?[]const u8 = null;
    for (req.messages) |msg| {
        if (std.mem.eql(u8, msg.role, "system")) {
            system_text = msg.content;
        }
    }
    if (system_text) |st| {
        try w.writeAll(",\"system\":\"");
        try jsonEscape(w, st);
        try w.writeAll("\"");
    }

    if (req.temperature) |t| try w.print(",\"temperature\":{d}", .{t});
    if (req.top_p) |tp| try w.print(",\"top_p\":{d}", .{tp});

    try w.writeAll(",\"messages\":[");
    var first = true;
    for (req.messages) |msg| {
        if (std.mem.eql(u8, msg.role, "system")) continue;
        if (!first) try w.writeAll(",");
        first = false;
        try w.writeAll("{\"role\":\"");
        try jsonEscape(w, msg.role);
        try w.writeAll("\",\"content\":\"");
        if (msg.content) |c| try jsonEscape(w, c);
        try w.writeAll("\"}");
    }
    try w.writeAll("]}");

    return try allocator.dupe(u8, buf.items);
}

/// Convert Claude messages request to OpenAI chat request.
pub fn toOpenAIReq(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(MessagesRequest, arena, raw_json, .{ .ignore_unknown_fields = true });
    const req = parsed.value;

    var msgs: std.ArrayList(openai.Message) = .empty;
    if (req.system) |s| try msgs.append(arena, .{ .role = "system", .content = s });
    for (req.messages) |m| try msgs.append(arena, .{ .role = m.role, .content = m.content });

    const oai = openai.ChatRequest{
        .model = model,
        .messages = msgs.items,
        .stream = req.stream,
        .temperature = req.temperature,
        .max_tokens = req.max_tokens,
        .top_p = req.top_p,
    };
    return try std.json.Stringify.valueAlloc(allocator, oai, .{ .emit_null_optional_fields = false });
}

/// Convert Claude messages response to OpenAI chat completion response.
pub fn toOpenAI(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(MessagesResponse, arena, raw_json, .{ .ignore_unknown_fields = true });
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

test "claude fromOpenAI converts request" {
    const openai_req = "{\"model\":\"claude-sonnet-4\",\"messages\":[{\"role\":\"system\",\"content\":\"Be helpful\"},{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":100}";
    const result = try fromOpenAI(std.testing.allocator, openai_req, "claude-sonnet-4");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Be helpful") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "claude-sonnet-4") != null);
}

test "claude toOpenAI converts response" {
    const claude_resp = "{\"id\":\"msg_01\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-sonnet-4\",\"content\":[{\"type\":\"text\",\"text\":\"Hello!\"}],\"stop_reason\":\"end_turn\"}";
    const result = try toOpenAI(std.testing.allocator, claude_resp, "claude-sonnet-4");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello!") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "chat.completion") != null);
}

test "parse claude messages request" {
    const json = "{\"model\":\"claude-sonnet-4\",\"max_tokens\":1024,\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}";
    const parsed = try std.json.parseFromSlice(MessagesRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("claude-sonnet-4", parsed.value.model);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.messages.len);
}
