const std = @import("std");

/// Map thinking budget tokens to reasoning effort level.
pub fn budgetToLevel(budget: i64) []const u8 {
    if (budget <= 0) return "medium";
    if (budget <= 4096) return "low";
    if (budget <= 16384) return "medium";
    return "high";
}

/// Map reasoning effort level to thinking budget tokens.
pub fn levelToBudget(level: []const u8) i64 {
    if (std.mem.eql(u8, level, "low")) return 4096;
    if (std.mem.eql(u8, level, "high")) return 32768;
    return 16384; // medium default
}

/// Map OpenAI reasoning_effort to Gemini thinkingConfig budget level string.
pub fn openaiToGeminiThinking(reasoning_effort: []const u8) []const u8 {
    if (std.mem.eql(u8, reasoning_effort, "low")) return "LOW";
    if (std.mem.eql(u8, reasoning_effort, "high")) return "HIGH";
    return "MEDIUM";
}

/// Extract thinking config from Claude budget_tokens and convert to OpenAI reasoning_effort.
pub fn claudeToOpenaiThinking(budget_tokens: i64) []const u8 {
    return budgetToLevel(budget_tokens);
}

test "budgetToLevel maps correctly" {
    try std.testing.expectEqualStrings("medium", budgetToLevel(0));
    try std.testing.expectEqualStrings("low", budgetToLevel(2048));
    try std.testing.expectEqualStrings("low", budgetToLevel(4096));
    try std.testing.expectEqualStrings("medium", budgetToLevel(8192));
    try std.testing.expectEqualStrings("medium", budgetToLevel(16384));
    try std.testing.expectEqualStrings("high", budgetToLevel(32768));
}

test "levelToBudget maps correctly" {
    try std.testing.expectEqual(@as(i64, 4096), levelToBudget("low"));
    try std.testing.expectEqual(@as(i64, 16384), levelToBudget("medium"));
    try std.testing.expectEqual(@as(i64, 32768), levelToBudget("high"));
    try std.testing.expectEqual(@as(i64, 16384), levelToBudget("unknown"));
}

test "openaiToGeminiThinking maps correctly" {
    try std.testing.expectEqualStrings("LOW", openaiToGeminiThinking("low"));
    try std.testing.expectEqualStrings("MEDIUM", openaiToGeminiThinking("medium"));
    try std.testing.expectEqualStrings("HIGH", openaiToGeminiThinking("high"));
}

test "claudeToOpenaiThinking maps correctly" {
    try std.testing.expectEqualStrings("low", claudeToOpenaiThinking(2048));
    try std.testing.expectEqualStrings("high", claudeToOpenaiThinking(32768));
}
