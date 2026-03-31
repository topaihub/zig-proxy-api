const std = @import("std");

pub const ConfigWatcher = struct {
    config_path: []const u8,
    last_mtime: i128,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !ConfigWatcher {
        return .{
            .allocator = allocator,
            .config_path = config_path,
            .last_mtime = (try std.fs.cwd().statFile(config_path)).mtime,
        };
    }

    pub fn check(self: *ConfigWatcher) !bool {
        const mtime = (try std.fs.cwd().statFile(self.config_path)).mtime;
        if (mtime != self.last_mtime) {
            self.last_mtime = mtime;
            return true;
        }
        return false;
    }

    pub fn deinit(self: *ConfigWatcher) void {
        _ = self;
    }
};

test "watcher detects file modification" {
    const path = "/tmp/_zig_proxy_watcher_test.json";
    {
        var f = try std.fs.cwd().createFile(path, .{});
        try f.writeAll("{}");
        f.close();
    }
    defer std.fs.cwd().deleteFile(path) catch {};

    var w = try ConfigWatcher.init(std.testing.allocator, path);
    defer w.deinit();

    // No change yet
    try std.testing.expect(!(try w.check()));

    // Modify file
    std.Thread.sleep(10 * std.time.ns_per_ms);
    {
        var f = try std.fs.cwd().createFile(path, .{});
        try f.writeAll("{\"port\": 1}");
        f.close();
    }

    // Should detect change
    try std.testing.expect(try w.check());
    // No new change
    try std.testing.expect(!(try w.check()));
}
