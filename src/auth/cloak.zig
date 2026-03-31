const std = @import("std");

pub const CloakMode = enum { auto, always, never };

pub const Cloak = struct {
    mode: CloakMode = .auto,
    strict_mode: bool = false,
    sensitive_words: []const []const u8 = &.{},

    pub fn obfuscate(allocator: std.mem.Allocator, text: []const u8, words: []const []const u8) ![]u8 {
        if (words.len == 0) return try allocator.dupe(u8, text);
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        var pos: usize = 0;
        while (pos < text.len) {
            var matched = false;
            for (words) |word| {
                if (word.len > 0 and pos + word.len <= text.len and std.mem.eql(u8, text[pos .. pos + word.len], word)) {
                    // Insert zero-width space (U+200B = 0xE2 0x80 0x8B) between each char of the word
                    for (word, 0..) |c, i| {
                        if (i > 0) try result.appendSlice(allocator, "\xe2\x80\x8b");
                        try result.append(allocator, c);
                    }
                    pos += word.len;
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                try result.append(allocator, text[pos]);
                pos += 1;
            }
        }
        return try result.toOwnedSlice(allocator);
    }

    pub fn shouldCloak(self: *const Cloak, user_agent: []const u8) bool {
        return switch (self.mode) {
            .always => true,
            .never => false,
            .auto => !isClaudeCodeClient(user_agent),
        };
    }
};

fn isClaudeCodeClient(ua: []const u8) bool {
    return std.mem.indexOf(u8, ua, "claude-cli") != null or
        std.mem.indexOf(u8, ua, "claude-code") != null;
}

test "cloak obfuscate inserts zero-width spaces" {
    const result = try Cloak.obfuscate(std.testing.allocator, "hello secret world", &.{"secret"});
    defer std.testing.allocator.free(result);
    // "secret" should be split with zero-width spaces, so result is longer
    try std.testing.expect(result.len > "hello secret world".len);
    // Original word should not appear as-is
    try std.testing.expect(std.mem.indexOf(u8, result, "secret") == null);
}

test "cloak obfuscate no words returns copy" {
    const result = try Cloak.obfuscate(std.testing.allocator, "hello", &.{});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "cloak shouldCloak modes" {
    const always = Cloak{ .mode = .always };
    try std.testing.expect(always.shouldCloak("anything"));

    const never = Cloak{ .mode = .never };
    try std.testing.expect(!never.shouldCloak("anything"));

    const auto = Cloak{ .mode = .auto };
    try std.testing.expect(auto.shouldCloak("curl/7.0"));
    try std.testing.expect(!auto.shouldCloak("claude-code/1.0"));
    try std.testing.expect(!auto.shouldCloak("claude-cli/2.0"));
}
