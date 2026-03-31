const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "Configuration" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  Config file: config.json\n");
    try writer.writeAll("  Press 'r' to reload configuration.\n");
}
