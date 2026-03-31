const std = @import("std");
const framework = @import("framework");

pub const server = @import("server/root.zig");

pub fn main() !void {
    const stdout = std.fs.File.stdout();
    try stdout.writeAll("zig-proxy-api bootstrap ready\n");
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}

test {
    std.testing.refAllDecls(@This());
}
