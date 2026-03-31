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

/// Parse data URI into mime_type and data components.
pub fn parseDataUri(uri: []const u8) ?struct { mime_type: []const u8, data: []const u8 } {
    if (!std.mem.startsWith(u8, uri, "data:")) return null;
    const after_data = uri[5..];
    const semi = std.mem.indexOfScalar(u8, after_data, ';') orelse return null;
    const mime = after_data[0..semi];
    const after_semi = after_data[semi + 1 ..];
    if (!std.mem.startsWith(u8, after_semi, "base64,")) return null;
    return .{ .mime_type = mime, .data = after_semi[7..] };
}

/// Convert OpenAI image_url content to Gemini inlineData.
pub fn openaiImageToGemini(allocator: std.mem.Allocator, image_url: []const u8) ![]u8 {
    const parsed = parseDataUri(image_url) orelse return error.InvalidDataUri;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"inlineData\":{\"mimeType\":\"");
    try jsonEscape(w, parsed.mime_type);
    try w.writeAll("\",\"data\":\"");
    try w.writeAll(parsed.data);
    try w.writeAll("\"}}");
    return try allocator.dupe(u8, buf.items);
}

/// Convert OpenAI image_url to Claude image content.
pub fn openaiImageToClaude(allocator: std.mem.Allocator, image_url: []const u8) ![]u8 {
    const parsed = parseDataUri(image_url) orelse return error.InvalidDataUri;

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"");
    try jsonEscape(w, parsed.mime_type);
    try w.writeAll("\",\"data\":\"");
    try w.writeAll(parsed.data);
    try w.writeAll("\"}}");
    return try allocator.dupe(u8, buf.items);
}

test "parseDataUri parses correctly" {
    const result = parseDataUri("data:image/png;base64,iVBORw0KGgo=").?;
    try std.testing.expectEqualStrings("image/png", result.mime_type);
    try std.testing.expectEqualStrings("iVBORw0KGgo=", result.data);
}

test "parseDataUri returns null for invalid" {
    try std.testing.expect(parseDataUri("https://example.com/img.png") == null);
    try std.testing.expect(parseDataUri("data:image/png,nobase64") == null);
}

test "openaiImageToGemini converts correctly" {
    const result = try openaiImageToGemini(std.testing.allocator, "data:image/jpeg;base64,/9j/4AAQ");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "inlineData") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "image/jpeg") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "/9j/4AAQ") != null);
}

test "openaiImageToClaude converts correctly" {
    const result = try openaiImageToClaude(std.testing.allocator, "data:image/png;base64,iVBORw0KGgo=");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"type\":\"image\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "media_type") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "image/png") != null);
}
