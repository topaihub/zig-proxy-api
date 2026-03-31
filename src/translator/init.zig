const std = @import("std");
const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const openai = @import("formats/openai.zig");
const gemini = @import("formats/gemini.zig");
const claude = @import("formats/claude.zig");

var arena_buf: [64 * 1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&arena_buf);

fn openaiToGeminiReq(_: []const u8, raw_json: []const u8, _: bool) []const u8 {
    fba.reset();
    return openai.toGemini(fba.allocator(), raw_json) catch return raw_json;
}

fn openaiToClaudeReq(model: []const u8, raw_json: []const u8, _: bool) []const u8 {
    fba.reset();
    return claude.fromOpenAI(fba.allocator(), raw_json, model) catch return raw_json;
}

fn geminiToOpenaiReq(model: []const u8, raw_json: []const u8, _: bool) []const u8 {
    fba.reset();
    return gemini.toOpenAI(fba.allocator(), raw_json, model) catch return raw_json;
}

/// Register all built-in translation pairs.
pub fn registerAll(reg: *registry_mod.Registry) void {
    reg.register(.openai, .gemini, openaiToGeminiReq, .{});
    reg.register(.openai, .claude, openaiToClaudeReq, .{});
    reg.register(.gemini, .openai, geminiToOpenaiReq, .{});
}

test "registerAll does not crash" {
    var reg = registry_mod.Registry.init(std.testing.allocator);
    defer reg.deinit();
    registerAll(&reg);

    // Verify a registered pair works
    const result = reg.translateRequest(.openai, .gemini, "model", "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}", false);
    try std.testing.expect(result.len > 0);
}
