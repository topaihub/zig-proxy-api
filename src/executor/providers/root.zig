pub const gemini = @import("gemini.zig");
pub const gemini_vertex = @import("gemini_vertex.zig");
pub const gemini_cli = @import("gemini_cli.zig");
pub const claude = @import("claude.zig");
pub const codex = @import("codex.zig");
pub const codex_ws = @import("codex_ws.zig");
pub const qwen = @import("qwen.zig");
pub const kimi = @import("kimi.zig");
pub const iflow = @import("iflow.zig");
pub const antigravity = @import("antigravity.zig");
pub const openai_compat = @import("openai_compat.zig");
pub const aistudio = @import("aistudio.zig");

const std = @import("std");

test "all provider executors initialize" {
    var g = gemini.GeminiExecutor.init("key");
    try std.testing.expectEqualStrings("gemini", g.executor().providerName());
    var gv = gemini_vertex.VertexExecutor.init("key");
    try std.testing.expectEqualStrings("gemini_vertex", gv.executor().providerName());
    var gc = gemini_cli.GeminiCliExecutor.init("key");
    try std.testing.expectEqualStrings("gemini_cli", gc.executor().providerName());
    var c = claude.ClaudeExecutor.init("key");
    try std.testing.expectEqualStrings("claude", c.executor().providerName());
    var cx = codex.CodexExecutor.init("key");
    try std.testing.expectEqualStrings("codex", cx.executor().providerName());
    var cw = codex_ws.CodexWsExecutor.init("key");
    try std.testing.expectEqualStrings("codex-ws", cw.executor().providerName());
    var q = qwen.QwenExecutor.init("key");
    try std.testing.expectEqualStrings("qwen", q.executor().providerName());
    var k = kimi.KimiExecutor.init("key");
    try std.testing.expectEqualStrings("kimi", k.executor().providerName());
    var i = iflow.IflowExecutor.init("key");
    try std.testing.expectEqualStrings("iflow", i.executor().providerName());
    var a = antigravity.AntigravityExecutor.init("key");
    try std.testing.expectEqualStrings("antigravity", a.executor().providerName());
    var oc = openai_compat.OpenAICompatExecutor.init("https://custom.api.com", "key");
    try std.testing.expectEqualStrings("openai_compat", oc.executor().providerName());
    var ai = aistudio.AiStudioExecutor.init("key");
    try std.testing.expectEqualStrings("aistudio", ai.executor().providerName());
}
