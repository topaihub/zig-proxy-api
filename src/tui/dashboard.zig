const ansi = @import("ansi.zig");

pub fn render(writer: anytype) !void {
    try writer.writeAll(ansi.bold ++ "Dashboard" ++ ansi.reset ++ "\n\n");
    try writer.writeAll("  Status: " ++ ansi.green ++ "Running" ++ ansi.reset ++ "\n");
    try writer.writeAll("  Uptime: -\n");
    try writer.writeAll("  Requests: 0\n");
    try writer.writeAll("  Active connections: 0\n");
}
