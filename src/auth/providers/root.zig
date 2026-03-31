pub const claude = @import("claude.zig");
pub const codex = @import("codex.zig");
pub const gemini = @import("gemini.zig");
pub const qwen = @import("qwen.zig");
pub const kimi = @import("kimi.zig");
pub const iflow = @import("iflow.zig");
pub const antigravity = @import("antigravity.zig");
pub const vertex = @import("vertex.zig");

const std = @import("std");

test "all auth providers initialize" {
    var c = claude.ClaudeAuth.init(std.testing.allocator);
    defer c.deinit();
    try std.testing.expectEqualStrings("claude", claude.ClaudeAuth.provider());

    var co = codex.CodexAuth.init(std.testing.allocator);
    defer co.deinit();
    try std.testing.expectEqualStrings("codex", codex.CodexAuth.provider());

    var g = gemini.GeminiAuth.init(std.testing.allocator);
    defer g.deinit();
    try std.testing.expectEqualStrings("gemini", gemini.GeminiAuth.provider());

    var q = qwen.QwenAuth.init(std.testing.allocator);
    defer q.deinit();
    try std.testing.expectEqualStrings("qwen", qwen.QwenAuth.provider());

    var k = kimi.KimiAuth.init(std.testing.allocator);
    defer k.deinit();
    try std.testing.expectEqualStrings("kimi", kimi.KimiAuth.provider());

    var i = iflow.IflowAuth.init(std.testing.allocator);
    defer i.deinit();
    try std.testing.expectEqualStrings("iflow", iflow.IflowAuth.provider());

    var a = antigravity.AntigravityAuth.init(std.testing.allocator);
    defer a.deinit();
    try std.testing.expectEqualStrings("antigravity", antigravity.AntigravityAuth.provider());

    var v = vertex.VertexAuth.init(std.testing.allocator);
    defer v.deinit();
    try std.testing.expectEqualStrings("vertex", vertex.VertexAuth.provider());
}
