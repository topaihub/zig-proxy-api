const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "API Keys" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  No API keys configured.\n");
}
