const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "Logs" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  No log entries.\n");
}
