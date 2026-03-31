const std = @import("std");
const types = @import("types.zig");

pub const LoadedConfig = struct {
    config: types.Config,
    _parsed: std.json.Parsed(types.Config),

    pub fn deinit(self: *LoadedConfig) void {
        self._parsed.deinit();
    }
};

pub fn loadFromString(json: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    const parsed = try std.json.parseFromSlice(types.Config, allocator, json, .{});
    return .{ .config = parsed.value, ._parsed = parsed };
}

pub fn loadFromFile(path: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);
    return loadFromString(content, allocator);
}

test "load config from json string" {
    const json = "{\"port\": 9000, \"host\": \"127.0.0.1\", \"debug\": true}";
    var cfg = try loadFromString(json, std.testing.allocator);
    defer cfg.deinit();
    try std.testing.expectEqual(@as(u16, 9000), cfg.config.port);
    try std.testing.expectEqualStrings("127.0.0.1", cfg.config.host);
    try std.testing.expectEqual(true, cfg.config.debug);
}

test "load config from file" {
    const content = "{\"port\": 7777}";
    var tmp = try std.fs.cwd().createFile("/tmp/_zig_proxy_test_cfg.json", .{});
    try tmp.writeAll(content);
    tmp.close();
    defer std.fs.cwd().deleteFile("/tmp/_zig_proxy_test_cfg.json") catch {};

    var cfg = try loadFromFile("/tmp/_zig_proxy_test_cfg.json", std.testing.allocator);
    defer cfg.deinit();
    try std.testing.expectEqual(@as(u16, 7777), cfg.config.port);
}

test "load config with defaults for missing fields" {
    const json = "{}";
    var cfg = try loadFromString(json, std.testing.allocator);
    defer cfg.deinit();
    try std.testing.expectEqual(@as(u16, 8317), cfg.config.port);
    try std.testing.expectEqual(@as(u8, 3), cfg.config.request_retry);
}
