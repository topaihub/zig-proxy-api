const std = @import("std");

pub const ModelPattern = struct {
    name: []const u8 = "",
};

pub const ParamOverride = struct {
    path: []const u8 = "",
    value: []const u8 = "",
};

pub const PayloadRule = struct {
    models: []const ModelPattern = &.{},
    protocol: []const u8 = "",
    params: []const ParamOverride = &.{},
};

fn matchModel(pattern: []const u8, model: []const u8) bool {
    if (pattern.len == 0) return true;
    if (std.mem.eql(u8, pattern, "*")) return true;
    if (std.mem.endsWith(u8, pattern, "*")) {
        return std.mem.startsWith(u8, model, pattern[0 .. pattern.len - 1]);
    }
    return std.mem.eql(u8, pattern, model);
}

fn ruleMatchesModel(rule: PayloadRule, model: []const u8) bool {
    if (rule.models.len == 0) return true;
    for (rule.models) |mp| {
        if (matchModel(mp.name, model)) return true;
    }
    return false;
}

pub fn applyDefaults(allocator: std.mem.Allocator, raw_json: []const u8, model: []const u8, rules: []const PayloadRule) ![]u8 {
    for (rules) |rule| {
        if (!ruleMatchesModel(rule, model)) continue;
        for (rule.params) |p| {
            _ = p;
        }
    }
    return try allocator.dupe(u8, raw_json);
}

test "payload rule model matching" {
    const rule = PayloadRule{ .models = &.{.{ .name = "claude-*" }} };
    try std.testing.expect(ruleMatchesModel(rule, "claude-sonnet"));
    try std.testing.expect(!ruleMatchesModel(rule, "gemini-pro"));
}

test "apply defaults returns json copy" {
    const json = "{\"model\":\"test\"}";
    const result = try applyDefaults(std.testing.allocator, json, "test", &.{});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(json, result);
}
