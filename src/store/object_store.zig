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

    fn objectPath(self: *ObjectStore, allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ self.endpoint, self.bucket, key });
    }

    fn bucketPath(self: *ObjectStore, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.endpoint, self.bucket });
    }

    const vtable = StoreBackend.VTable{
        .get = get,
        .put = put,
        .delete = delete,
        .list_keys = listKeys,
        .name = name,
    };

    fn get(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8 {
        const self: *ObjectStore = @ptrCast(@alignCast(ptr));
        const path = try self.objectPath(allocator, key);
        defer allocator.free(path);
        const file = std.fs.cwd().openFile(path, .{}) catch return null;
        defer file.close();
        return try file.readToEndAlloc(allocator, 1 << 20);
    }

    fn put(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, value: []const u8) anyerror!void {
        const self: *ObjectStore = @ptrCast(@alignCast(ptr));
        const bp = try self.bucketPath(allocator);
        defer allocator.free(bp);
        std.fs.cwd().makePath(bp) catch {};
        const path = try self.objectPath(allocator, key);
        defer allocator.free(path);
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(value);
    }

    fn delete(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void {
        const self: *ObjectStore = @ptrCast(@alignCast(ptr));
        const path = try self.objectPath(allocator, key);
        defer allocator.free(path);
        std.fs.cwd().deleteFile(path) catch {};
    }

    fn listKeys(ptr: *anyopaque, allocator: std.mem.Allocator, prefix: []const u8) anyerror![]const []const u8 {
        const self: *ObjectStore = @ptrCast(@alignCast(ptr));
        const bp = try self.bucketPath(allocator);
        defer allocator.free(bp);
        var dir = std.fs.cwd().openDir(bp, .{ .iterate = true }) catch return try allocator.alloc([]const u8, 0);
        defer dir.close();
        var list: std.ArrayList([]const u8) = .empty;
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (prefix.len == 0 or std.mem.startsWith(u8, entry.name, prefix)) {
                try list.append(allocator, try allocator.dupe(u8, entry.name));
            }
        }
        return try list.toOwnedSlice(allocator);
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

test "object store put and get" {
    const dir = "_zig_proxy_obj_store_test";
    std.fs.cwd().deleteTree(dir) catch {};
    defer std.fs.cwd().deleteTree(dir) catch {};
    var os = ObjectStore.init(std.testing.allocator, dir, "testbucket");
    var b = os.backend();
    try b.put(std.testing.allocator, "key1", "{\"data\":1}");
    const val = try b.get(std.testing.allocator, "key1");
    try std.testing.expect(val != null);
    defer std.testing.allocator.free(val.?);
    try std.testing.expect(std.mem.indexOf(u8, val.?, "data") != null);
}
