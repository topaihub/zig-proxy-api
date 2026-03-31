const std = @import("std");
const framework = @import("framework");
const watcher_mod = @import("watcher.zig");
const loader_mod = @import("loader.zig");
const diff_mod = @import("diff.zig");
const types = @import("types.zig");

pub const HotReloader = struct {
    allocator: std.mem.Allocator,
    watcher: watcher_mod.ConfigWatcher,
    config_path: []const u8,
    current_config: types.Config,
    event_bus: ?framework.EventBus = null,
    logger: ?*framework.Logger = null,
    poll_interval_ms: u64 = 2000,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8, initial_config: types.Config) !HotReloader {
        return .{
            .allocator = allocator,
            .watcher = try watcher_mod.ConfigWatcher.init(allocator, config_path),
            .config_path = config_path,
            .current_config = initial_config,
        };
    }

    pub fn setEventBus(self: *HotReloader, bus: framework.EventBus) void {
        self.event_bus = bus;
    }

    pub fn setLogger(self: *HotReloader, logger: *framework.Logger) void {
        self.logger = logger;
    }

    /// Check for changes once. Returns true if config was reloaded.
    pub fn checkOnce(self: *HotReloader) !bool {
        const changed = try self.watcher.check();
        if (!changed) return false;

        // Reload config
        var loaded = loader_mod.loadFromFile(self.config_path, self.allocator) catch |err| {
            if (self.logger) |l| l.subsystem("config").warn("hot-reload failed", &.{
                framework.LogField.string("path", self.config_path),
                framework.LogField.string("error", @errorName(err)),
            });
            return err;
        };
        defer loaded.deinit();

        // Compute diff
        const changes = diff_mod.diff(&self.current_config, &loaded.config);
        if (!changes.any_changed) return false;

        // Update current config
        self.current_config = loaded.config;

        // Publish event
        if (self.event_bus) |bus| {
            _ = bus.publish("config.reloaded", "{\"source\":\"file_watcher\"}") catch {};
        }

        if (self.logger) |l| l.subsystem("config").info("configuration reloaded", &.{
            framework.LogField.string("path", self.config_path),
        });
        return true;
    }

    /// Start polling loop (blocking). Call from a separate thread.
    pub fn startPolling(self: *HotReloader) void {
        self.running.store(true, .release);
        while (self.running.load(.acquire)) {
            _ = self.checkOnce() catch {};
            std.Thread.sleep(self.poll_interval_ms * std.time.ns_per_ms);
        }
    }

    pub fn stop(self: *HotReloader) void {
        self.running.store(false, .release);
    }

    pub fn deinit(self: *HotReloader) void {
        self.watcher.deinit();
    }
};

test "hot reloader detects config change" {
    const path = "/tmp/_zig_proxy_hotreload_test.json";
    {
        var f = try std.fs.cwd().createFile(path, .{});
        try f.writeAll("{\"port\": 8317}");
        f.close();
    }
    defer std.fs.cwd().deleteFile(path) catch {};

    var hr = try HotReloader.init(std.testing.allocator, path, .{});
    defer hr.deinit();

    // No change yet
    try std.testing.expect(!(try hr.checkOnce()));

    // Modify file
    std.Thread.sleep(10 * std.time.ns_per_ms);
    {
        var f = try std.fs.cwd().createFile(path, .{});
        try f.writeAll("{\"port\": 9999}");
        f.close();
    }

    // Should detect and reload
    try std.testing.expect(try hr.checkOnce());
    try std.testing.expectEqual(@as(u16, 9999), hr.current_config.port);
}
