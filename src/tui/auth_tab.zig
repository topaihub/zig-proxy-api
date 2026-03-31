const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "Authentication" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  No auth records loaded.\n");
    try writer.writeAll("  Use management API to add credentials.\n");
}
