const std = @import("std");
const StoreBackend = @import("types.zig").StoreBackend;

pub const GitStore = struct {
    repo_path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) GitStore {
        return .{ .allocator = allocator, .repo_path = repo_path };
    }

    pub fn deinit(self: *GitStore) void {
        _ = self;
    }

    pub fn backend(self: *GitStore) StoreBackend {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    fn dataPath(self: *GitStore, allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/data/{s}.json", .{ self.repo_path, key });
    }

    fn ensureDirs(self: *GitStore) !void {
        const data_path = try std.fmt.allocPrint(self.allocator, "{s}/data", .{self.repo_path});
        defer self.allocator.free(data_path);
        std.fs.cwd().makePath(data_path) catch {};
    }

    fn appendLog(self: *GitStore, op: []const u8, key: []const u8) void {
        const log_path = std.fmt.allocPrint(self.allocator, "{s}/log.jsonl", .{self.repo_path}) catch return;
        defer self.allocator.free(log_path);
        const file = std.fs.cwd().openFile(log_path, .{ .mode = .write_only }) catch
            std.fs.cwd().createFile(log_path, .{}) catch return;
        defer file.close();
        file.seekFromEnd(0) catch {};
        var buf: [1024]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{{\"op\":\"{s}\",\"key\":\"{s}\"}}\n", .{ op, key }) catch return;
        _ = file.write(line) catch {};
    }

    const vtable = StoreBackend.VTable{
        .get = get,
        .put = put,
        .delete = delete,
        .list_keys = listKeys,
        .name = name,
    };

    fn get(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8 {
        const self: *GitStore = @ptrCast(@alignCast(ptr));
        const path = try self.dataPath(allocator, key);
        defer allocator.free(path);
        const file = std.fs.cwd().openFile(path, .{}) catch return null;
        defer file.close();
        return try file.readToEndAlloc(allocator, 1 << 20);
    }

    fn put(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, value: []const u8) anyerror!void {
        const self: *GitStore = @ptrCast(@alignCast(ptr));
        try self.ensureDirs();
        const path = try self.dataPath(allocator, key);
        defer allocator.free(path);
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(value);
        self.appendLog("put", key);
    }

    fn delete(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void {
        const self: *GitStore = @ptrCast(@alignCast(ptr));
        const path = try self.dataPath(allocator, key);
        defer allocator.free(path);
        std.fs.cwd().deleteFile(path) catch {};
        self.appendLog("delete", key);
    }

    fn listKeys(ptr: *anyopaque, allocator: std.mem.Allocator, prefix: []const u8) anyerror![]const []const u8 {
        const self: *GitStore = @ptrCast(@alignCast(ptr));
        const dir_path = try std.fmt.allocPrint(allocator, "{s}/data", .{self.repo_path});
        defer allocator.free(dir_path);
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return try allocator.alloc([]const u8, 0);
        defer dir.close();
        var list = std.ArrayList([]const u8).init(allocator);
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            const n = entry.name;
            if (!std.mem.endsWith(u8, n, ".json")) continue;
            const key = n[0 .. n.len - 5];
            if (prefix.len == 0 or std.mem.startsWith(u8, key, prefix)) {
                try list.append(try allocator.dupe(u8, key));
            }
        }
        return try list.toOwnedSlice();
    }

    fn name(_: *anyopaque) []const u8 {
        return "git";
    }
};

test "git store has correct name" {
    var gs = GitStore.init(std.testing.allocator, "/tmp/repo");
    defer gs.deinit();
    const b = gs.backend();
    try std.testing.expectEqualStrings("git", b.backendName());
}

test "git store put and get" {
    const dir = "/tmp/_zig_proxy_git_store_test";
    std.fs.cwd().deleteTree(dir) catch {};
    defer std.fs.cwd().deleteTree(dir) catch {};
    var gs = GitStore.init(std.testing.allocator, dir);
    var b = gs.backend();
    try b.put(std.testing.allocator, "key1", "{\"data\":1}");
    const val = try b.get(std.testing.allocator, "key1");
    try std.testing.expect(val != null);
    defer std.testing.allocator.free(val.?);
    try std.testing.expect(std.mem.indexOf(u8, val.?, "data") != null);
}
