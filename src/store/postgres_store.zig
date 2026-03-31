const std = @import("std");
const StoreBackend = @import("types.zig").StoreBackend;

pub const PostgresStore = struct {
    connection_url: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, connection_url: []const u8) PostgresStore {
        return .{ .allocator = allocator, .connection_url = connection_url };
    }

    pub fn deinit(self: *PostgresStore) void {
        _ = self;
    }

    pub fn backend(self: *PostgresStore) StoreBackend {
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
        return "postgres";
    }
};

test "postgres store has correct name" {
    var ps = PostgresStore.init(std.testing.allocator, "postgresql://localhost/test");
    defer ps.deinit();
    const b = ps.backend();
    try std.testing.expectEqualStrings("postgres", b.backendName());
}
