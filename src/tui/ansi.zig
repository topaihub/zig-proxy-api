pub const reset = "\x1b[0m";
pub const bold = "\x1b[1m";
pub const dim = "\x1b[2m";
pub const red = "\x1b[31m";
pub const green = "\x1b[32m";
pub const yellow = "\x1b[33m";
pub const blue = "\x1b[34m";
pub const cyan = "\x1b[36m";
pub const white = "\x1b[37m";
pub const bg_blue = "\x1b[44m";
pub const clear_screen = "\x1b[2J\x1b[H";
pub const clear_line = "\x1b[2K";
pub const hide_cursor = "\x1b[?25l";
pub const show_cursor = "\x1b[?25h";

pub fn moveTo(writer: anytype, row: u16, col: u16) !void {
    try writer.print("\x1b[{d};{d}H", .{ row, col });
}

const std = @import("std");

test "escape codes are non-empty" {
    const codes = [_][]const u8{ reset, bold, dim, red, green, yellow, blue, cyan, white, bg_blue, clear_screen, clear_line, hide_cursor, show_cursor };
    for (codes) |code| {
        try std.testing.expect(code.len > 0);
    }
}
