const std = @import("std");
const StoreBackend = @import("types.zig").StoreBackend;

pub const ObjectStore = struct {
    endpoint: []const u8,
    bucket: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8, bucket: []const u8) ObjectStore {
        return .{ .allocator = allocator, .endpoint = endpoint, .bucket = bucket };
    }

    pub fn deinit(self: *ObjectStore) void {
        _ = self;
    }

    pub fn backend(self: *ObjectStore) StoreBackend {
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
        return "object";
    }
};

test "object store has correct name" {
    var os = ObjectStore.init(std.testing.allocator, "https://s3.amazonaws.com", "my-bucket");
    defer os.deinit();
    const b = os.backend();
    try std.testing.expectEqualStrings("object", b.backendName());
}
