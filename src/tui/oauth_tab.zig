const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "OAuth" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  Providers: gemini, claude, codex, qwen, kimi, iflow, antigravity\n");
    try writer.writeAll("  Use management API to initiate OAuth login.\n");
}
