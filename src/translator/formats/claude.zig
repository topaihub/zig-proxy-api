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

test "parse claude messages request" {
    const json = "{\"model\":\"claude-sonnet-4\",\"max_tokens\":1024,\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}";
    const parsed = try std.json.parseFromSlice(MessagesRequest, std.testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("claude-sonnet-4", parsed.value.model);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.messages.len);
}
