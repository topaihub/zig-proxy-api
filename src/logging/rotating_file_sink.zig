const std = @import("std");
const framework = @import("framework");

const MAX_FILE_SIZE: u64 = 100 * 1024 * 1024;

pub const RotatingFileSink = struct {
    allocator: std.mem.Allocator,
    log_dir: []const u8,
    prefix: []const u8,
    current_date: [10]u8 = .{0} ** 10,
    current_file: ?std.fs.File = null,
    current_size: u64 = 0,
    current_part: u32 = 0,
    mutex: std.Thread.Mutex = .{},

    const vtable = framework.LogSink.VTable{
        .write = writeErased,
        .flush = flushErased,
        .deinit = deinitErased,
        .name = nameErased,
    };

    pub fn init(allocator: std.mem.Allocator, log_dir: []const u8, prefix: []const u8) RotatingFileSink {
        std.fs.cwd().makePath(log_dir) catch {};
        return .{ .allocator = allocator, .log_dir = log_dir, .prefix = prefix };
    }

    pub fn deinit(self: *RotatingFileSink) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.current_file) |f| {
            var file = f;
            file.close();
        }
    }

    pub fn asLogSink(self: *RotatingFileSink) framework.LogSink {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    fn writeErased(ptr: *anyopaque, record: *const framework.LogRecord) void {
        const self: *RotatingFileSink = @ptrCast(@alignCast(ptr));
        self.writeRecord(record);
    }

    fn flushErased(_: *anyopaque) void {}

    fn deinitErased(ptr: *anyopaque) void {
        const self: *RotatingFileSink = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "rotating_file";
    }

    fn writeRecord(self: *RotatingFileSink, record: *const framework.LogRecord) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.writeRecordInternal(record) catch {};
    }

    fn writeRecordInternal(self: *RotatingFileSink, record: *const framework.LogRecord) !void {
        var date_buf: [10]u8 = undefined;
        const date_str = epochToDate(@intCast(@max(0, @divTrunc(record.ts_unix_ms, 1000))), &date_buf);

        const date_changed = !std.mem.eql(u8, self.current_date[0..10], date_str);
        const size_exceeded = self.current_size >= MAX_FILE_SIZE;

        if (self.current_file == null or date_changed or size_exceeded) {
            if (self.current_file) |f| {
                var file = f;
                file.close();
                self.current_file = null;
            }
            if (date_changed) {
                @memcpy(&self.current_date, date_str);
                self.current_part = 0;
            } else if (size_exceeded) {
                self.current_part += 1;
            }
            self.current_size = 0;

            var path_buf: [256]u8 = undefined;
            const path = if (self.current_part == 0)
                std.fmt.bufPrint(&path_buf, "{s}/{s}-{s}.log", .{ self.log_dir, self.prefix, date_str }) catch return error.PathTooLong
            else
                std.fmt.bufPrint(&path_buf, "{s}/{s}-{s}.{d}.log", .{ self.log_dir, self.prefix, date_str, self.current_part }) catch return error.PathTooLong;

            var file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false }),
                else => return err,
            };
            const stat = try file.stat();
            self.current_size = stat.size;
            try file.seekFromEnd(0);
            self.current_file = file;
        }

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try record.writeJson(buf.writer(self.allocator));
        try buf.append(self.allocator, '\n');

        if (self.current_file) |f| {
            try f.writeAll(buf.items);
            self.current_size += buf.items.len;
        }
    }
};

fn epochToDate(epoch_secs: u64, buf: *[10]u8) []const u8 {
    const days = epoch_secs / 86400;
    var d = days;
    var y: u32 = 1970;
    while (true) {
        const diy: u64 = if (isLeap(y)) 366 else 365;
        if (d < diy) break;
        d -= diy;
        y += 1;
    }
    const mdays = if (isLeap(y))
        [_]u8{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    else
        [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 0;
    while (m < 12) : (m += 1) {
        if (d < mdays[m]) break;
        d -= mdays[m];
    }
    _ = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{ y, m + 1, @as(u32, @intCast(d)) + 1 }) catch {};
    return buf[0..10];
}

fn isLeap(y: u32) bool {
    return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0);
}

test "epochToDate produces correct date for epoch zero" {
    var buf: [10]u8 = undefined;
    const d = epochToDate(0, &buf);
    try std.testing.expectEqualStrings("1970-01-01", d);
}

test "epochToDate produces correct date for known timestamp" {
    var buf: [10]u8 = undefined;
    // 2025-01-15 = 20103 days since epoch
    const d = epochToDate(1736899200, &buf);
    try std.testing.expectEqualStrings("2025-01-15", d);
}
