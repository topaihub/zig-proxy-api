const std = @import("std");

pub const ModelAlias = struct {
    name: []const u8,
    alias: []const u8,
};

pub const ModelRegistry = struct {
    aliases: []const ModelAlias = &.{},
    excluded: []const []const u8 = &.{},

    pub fn resolveAlias(self: *const ModelRegistry, model: []const u8) []const u8 {
        for (self.aliases) |a| {
            if (std.mem.eql(u8, a.name, model)) return a.alias;
        }
        return model;
    }

    pub fn isExcluded(self: *const ModelRegistry, model: []const u8) bool {
        for (self.excluded) |pattern| {
            if (matchPattern(pattern, model)) return true;
        }
        return false;
    }

    fn matchPattern(pattern: []const u8, model: []const u8) bool {
        // exact match
        if (std.mem.eql(u8, pattern, model)) return true;
        // prefix wildcard: "gemini-*"
        if (pattern.len > 1 and pattern[pattern.len - 1] == '*' and pattern[0] != '*') {
            return std.mem.startsWith(u8, model, pattern[0 .. pattern.len - 1]);
        }
        // suffix wildcard: "*-preview"
        if (pattern.len > 1 and pattern[0] == '*' and pattern[pattern.len - 1] != '*') {
            return std.mem.endsWith(u8, model, pattern[1..]);
        }
        // contains wildcard: "*flash*"
        if (pattern.len > 2 and pattern[0] == '*' and pattern[pattern.len - 1] == '*') {
            return std.mem.indexOf(u8, model, pattern[1 .. pattern.len - 1]) != null;
        }
        return false;
    }
};

test "alias resolution" {
    const aliases = [_]ModelAlias{
        .{ .name = "gpt4", .alias = "gpt-4-turbo" },
    };
    const reg = ModelRegistry{ .aliases = &aliases };
    try std.testing.expectEqualStrings("gpt-4-turbo", reg.resolveAlias("gpt4"));
    try std.testing.expectEqualStrings("unknown", reg.resolveAlias("unknown"));
}

test "exact exclusion match" {
    const excluded = [_][]const u8{"gpt-4"};
    const reg = ModelRegistry{ .excluded = &excluded };
    try std.testing.expect(reg.isExcluded("gpt-4"));
    try std.testing.expect(!reg.isExcluded("gpt-4-turbo"));
}

test "wildcard prefix exclusion" {
    const excluded = [_][]const u8{"gemini-*"};
    const reg = ModelRegistry{ .excluded = &excluded };
    try std.testing.expect(reg.isExcluded("gemini-pro"));
    try std.testing.expect(reg.isExcluded("gemini-2.5-flash"));
    try std.testing.expect(!reg.isExcluded("claude-3"));
}

test "wildcard suffix exclusion" {
    const excluded = [_][]const u8{"*-preview"};
    const reg = ModelRegistry{ .excluded = &excluded };
    try std.testing.expect(reg.isExcluded("gpt-4-preview"));
    try std.testing.expect(!reg.isExcluded("gpt-4"));
}

test "wildcard contains exclusion" {
    const excluded = [_][]const u8{"*flash*"};
    const reg = ModelRegistry{ .excluded = &excluded };
    try std.testing.expect(reg.isExcluded("gemini-2.5-flash-preview"));
    try std.testing.expect(reg.isExcluded("flash-lite"));
    try std.testing.expect(!reg.isExcluded("gpt-4"));
}
