const std = @import("std");

pub const SseWriter = struct {
    buf: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    pub fn initTest(buf: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) SseWriter {
        return .{ .buf = buf, .allocator = allocator };
    }

    pub fn writeEvent(self: *SseWriter, data: []const u8) !void {
        try self.buf.appendSlice(self.allocator, data);
    }

    pub fn writeKeepAlive(self: *SseWriter) !void {
        try self.buf.appendSlice(self.allocator, ": keep-alive\n\n");
    }

    pub fn writeData(self: *SseWriter, data: []const u8) !void {
        try self.buf.appendSlice(self.allocator, "data: ");
        try self.buf.appendSlice(self.allocator, data);
        try self.buf.appendSlice(self.allocator, "\n\n");
    }

    pub fn writeDone(self: *SseWriter) !void {
        try self.buf.appendSlice(self.allocator, "data: [DONE]\n\n");
    }

    pub fn flush(self: *SseWriter) !void {
        _ = self;
    }
};

test "sse writer formats events correctly" {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(std.testing.allocator);
    var writer = SseWriter.initTest(&buf, std.testing.allocator);
    try writer.writeData("{\"chunk\":1}");
    try writer.writeKeepAlive();
    const output = buf.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "data: {\"chunk\":1}\n\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, ": keep-alive\n\n") != null);
}
