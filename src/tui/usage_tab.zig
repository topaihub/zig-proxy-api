const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "Usage Statistics" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  Total requests: 0\n");
    try writer.writeAll("  Total tokens: 0\n");
}
