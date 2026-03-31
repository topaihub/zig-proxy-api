const std = @import("std");

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

const Tool = struct {
    type: []const u8 = "function",
    function: ?Function = null,
};

const Function = struct {
    name: []const u8 = "",
    description: ?[]const u8 = null,
    parameters: ?std.json.Value = null,
};

const ToolsWrapper = struct {
    tools: []const Tool = &.{},
};

/// Convert OpenAI tools format to Gemini functionDeclarations format.
pub fn openaiToolsToGemini(allocator: std.mem.Allocator, tools_json: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(ToolsWrapper, arena, tools_json, .{ .ignore_unknown_fields = true });
    const tools = parsed.value.tools;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"tools\":[{\"functionDeclarations\":[");
    var first = true;
    for (tools) |tool| {
        if (tool.function) |func| {
            if (!first) try w.writeAll(",");
            first = false;
            try w.writeAll("{\"name\":\"");
            try jsonEscape(w, func.name);
            try w.writeAll("\"");
            if (func.description) |d| {
                try w.writeAll(",\"description\":\"");
                try jsonEscape(w, d);
                try w.writeAll("\"");
            }
            if (func.parameters) |params| {
                try w.writeAll(",\"parameters\":");
                try std.json.stringify(params, .{}, w);
            }
            try w.writeAll("}");
        }
    }
    try w.writeAll("]}]}");
    return try allocator.dupe(u8, buf.items);
}

const ToolCall = struct {
    id: []const u8 = "",
    function: ?ToolCallFunction = null,
};

const ToolCallFunction = struct {
    name: []const u8 = "",
    arguments: []const u8 = "",
};

const ToolCallsWrapper = struct {
    tool_calls: []const ToolCall = &.{},
};

/// Convert OpenAI tool call response to Gemini functionCall.
pub fn openaiToolCallToGemini(allocator: std.mem.Allocator, tool_call_json: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(ToolCallsWrapper, arena, tool_call_json, .{ .ignore_unknown_fields = true });
    const calls = parsed.value.tool_calls;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    if (calls.len > 0) {
        if (calls[0].function) |func| {
            try w.writeAll("{\"functionCall\":{\"name\":\"");
            try jsonEscape(w, func.name);
            try w.writeAll("\",\"args\":");
            // arguments is a JSON string, write it directly
            if (func.arguments.len > 0) {
                try w.writeAll(func.arguments);
            } else {
                try w.writeAll("{}");
            }
            try w.writeAll("}}");
        }
    }
    return try allocator.dupe(u8, buf.items);
}

/// Convert OpenAI tools to Claude tools format.
pub fn openaiToolsToClaude(allocator: std.mem.Allocator, tools_json: []const u8) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const parsed = try std.json.parseFromSlice(ToolsWrapper, arena, tools_json, .{ .ignore_unknown_fields = true });
    const tools = parsed.value.tools;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"tools\":[");
    var first = true;
    for (tools) |tool| {
        if (tool.function) |func| {
            if (!first) try w.writeAll(",");
            first = false;
            try w.writeAll("{\"name\":\"");
            try jsonEscape(w, func.name);
            try w.writeAll("\"");
            if (func.description) |d| {
                try w.writeAll(",\"description\":\"");
                try jsonEscape(w, d);
                try w.writeAll("\"");
            }
            if (func.parameters) |params| {
                try w.writeAll(",\"input_schema\":");
                try std.json.stringify(params, .{}, w);
            }
            try w.writeAll("}");
        }
    }
    try w.writeAll("]}");
    return try allocator.dupe(u8, buf.items);
}

test "openaiToolsToGemini converts correctly" {
    const input =
        \\{"tools":[{"type":"function","function":{"name":"get_weather","description":"Get weather","parameters":{"type":"object"}}}]}
    ;
    const result = try openaiToolsToGemini(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "functionDeclarations") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "get_weather") != null);
}

test "openaiToolCallToGemini converts correctly" {
    const input =
        \\{"tool_calls":[{"id":"call_1","function":{"name":"get_weather","arguments":"{\"city\":\"NYC\"}"}}]}
    ;
    const result = try openaiToolCallToGemini(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "functionCall") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "get_weather") != null);
}

test "openaiToolsToClaude converts correctly" {
    const input =
        \\{"tools":[{"type":"function","function":{"name":"get_weather","description":"Get weather","parameters":{"type":"object"}}}]}
    ;
    const result = try openaiToolsToClaude(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "input_schema") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "get_weather") != null);
}
