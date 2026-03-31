pub const gemini = "gemini";
pub const gemini_cli = "gemini-cli";
pub const aistudio = "aistudio";
pub const vertex = "vertex";
pub const claude = "claude";
pub const codex = "codex";
pub const qwen = "qwen";
pub const kimi = "kimi";
pub const iflow = "iflow";
pub const antigravity = "antigravity";

pub const all = [_][]const u8{ gemini, gemini_cli, aistudio, vertex, claude, codex, qwen, kimi, iflow, antigravity };

const std = @import("std");

test "all providers list has 10 entries" {
    try std.testing.expectEqual(@as(usize, 10), all.len);
}
