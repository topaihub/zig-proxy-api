const std = @import("std");

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

test "parse codex responses request" {
    const json = "{\"model\":\"gpt-5-codex\",\"input\":\"hello\",\"stream\":true}";
    const parsed = try std.json.parseFromSlice(ResponsesRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("gpt-5-codex", parsed.value.model);
    try std.testing.expectEqual(true, parsed.value.stream);
}
