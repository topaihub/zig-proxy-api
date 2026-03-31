const std = @import("std");

pub const RequestLogEntry = struct {
    timestamp: i64 = 0,
    method: []const u8 = "",
    path: []const u8 = "",
    status: u16 = 0,
    duration_ms: u64 = 0,
    model: []const u8 = "",
    provider: []const u8 = "",
    request_id: []const u8 = "",
};

pub const RequestLogger = struct {
    allocator: std.mem.Allocator,
    log_dir: []const u8,
    enabled: bool = true,
    max_files: u32 = 10,

    pub fn init(allocator: std.mem.Allocator, log_dir: []const u8) RequestLogger {
        return .{ .allocator = allocator, .log_dir = log_dir };
    }

    pub fn setEnabled(self: *RequestLogger, enabled: bool) void {
        self.enabled = enabled;
    }

    pub fn isEnabled(self: *const RequestLogger) bool {
        return self.enabled;
    }

    pub fn log(self: *RequestLogger, entry: RequestLogEntry) !void {
        if (!self.enabled) return;
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);
        const w = buf.writer(self.allocator);
        try w.print("{{\"ts\":{d},\"method\":\"{s}\",\"path\":\"{s}\",\"status\":{d},\"ms\":{d},\"model\":\"{s}\",\"provider\":\"{s}\",\"rid\":\"{s}\"}}\n", .{
            entry.timestamp, entry.method, entry.path, entry.status,
            entry.duration_ms, entry.model, entry.provider, entry.request_id,
        });
        // In production, append to file in log_dir. For now, just format.
        _ = buf.items;
    }

    pub fn deinit(self: *RequestLogger) void {
        _ = self;
    }
};

test "request logger init and toggle" {
    var logger = RequestLogger.init(std.testing.allocator, "/tmp/logs");
    defer logger.deinit();
    try std.testing.expect(logger.isEnabled());
    logger.setEnabled(false);
    try std.testing.expect(!logger.isEnabled());
}

test "request logger formats entry" {
    var logger = RequestLogger.init(std.testing.allocator, "/tmp/logs");
    defer logger.deinit();
    try logger.log(.{ .method = "GET", .path = "/v1/models", .status = 200 });
}
