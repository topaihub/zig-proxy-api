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

    const vtable = StoreBackend.VTable{
        .get = get,
        .put = put,
        .delete = delete,
        .list_keys = listKeys,
        .name = name,
    };

    fn get(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8 {
        _ = ptr;
        _ = allocator;
        _ = key;
        return error.NotImplemented;
    }

    fn put(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, value: []const u8) anyerror!void {
        _ = ptr;
        _ = allocator;
        _ = key;
        _ = value;
        return error.NotImplemented;
    }

    fn delete(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void {
        _ = ptr;
        _ = allocator;
        _ = key;
        return error.NotImplemented;
    }

    fn listKeys(ptr: *anyopaque, allocator: std.mem.Allocator, prefix: []const u8) anyerror![]const []const u8 {
        _ = ptr;
        _ = allocator;
        _ = prefix;
        return error.NotImplemented;
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
