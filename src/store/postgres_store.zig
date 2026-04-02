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

    fn dbPath(self: *PostgresStore, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/db.jsonl", .{self.connection_url});
    }

    const Entry = struct { key: []const u8, value: []const u8 };

    fn readAll(self: *PostgresStore, allocator: std.mem.Allocator) ![]Entry {
        const path = try self.dbPath(allocator);
        defer allocator.free(path);
        const content = std.fs.cwd().readFileAlloc(allocator, path, 1 << 20) catch return try allocator.alloc(Entry, 0);
        defer allocator.free(content);
        var list: std.ArrayList(Entry) = .empty;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const k = extractField(line, "key") orelse continue;
            const v = extractField(line, "value") orelse continue;
            try list.append(allocator, .{ .key = try allocator.dupe(u8, k), .value = try allocator.dupe(u8, v) });
        }
        return try list.toOwnedSlice(allocator);
    }

    fn extractField(line: []const u8, field: []const u8) ?[]const u8 {
        var buf: [64]u8 = undefined;
        const needle = std.fmt.bufPrint(&buf, "\"{s}\":\"", .{field}) catch return null;
        const start_idx = (std.mem.indexOf(u8, line, needle) orelse return null) + needle.len;
        const rest = line[start_idx..];
        const end = std.mem.indexOfScalar(u8, rest, '"') orelse return null;
        return rest[0..end];
    }

    fn writeAll(self: *PostgresStore, allocator: std.mem.Allocator, entries: []const Entry) !void {
        const path = try self.dbPath(allocator);
        defer allocator.free(path);
        if (std.mem.lastIndexOfScalar(u8, path, '/')) |idx| {
            std.fs.cwd().makePath(path[0..idx]) catch {};
        }
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        for (entries) |e| {
            const line = try std.fmt.allocPrint(allocator, "{{\"key\":\"{s}\",\"value\":\"{s}\"}}\n", .{ e.key, e.value });
            defer allocator.free(line);
            try file.writeAll(line);
        }
    }

    fn freeEntries(allocator: std.mem.Allocator, entries: []Entry) void {
        for (entries) |e| {
            allocator.free(e.key);
            allocator.free(e.value);
        }
        allocator.free(entries);
    }

    const vtable = StoreBackend.VTable{
        .get = get,
        .put = put,
        .delete = delete,
        .list_keys = listKeys,
        .name = name,
    };

    fn get(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8 {
        const self: *PostgresStore = @ptrCast(@alignCast(ptr));
        const entries = try self.readAll(allocator);
        defer freeEntries(allocator, entries);
        for (entries) |e| {
            if (std.mem.eql(u8, e.key, key)) return try allocator.dupe(u8, e.value);
        }
        return null;
    }

    fn put(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, value: []const u8) anyerror!void {
        const self: *PostgresStore = @ptrCast(@alignCast(ptr));
        const entries = try self.readAll(allocator);
        defer freeEntries(allocator, entries);
        var list: std.ArrayList(Entry) = .empty;
        defer list.deinit(allocator);
        var found = false;
        for (entries) |e| {
            if (std.mem.eql(u8, e.key, key)) {
                try list.append(allocator, .{ .key = e.key, .value = value });
                found = true;
            } else {
                try list.append(allocator, e);
            }
        }
        if (!found) try list.append(allocator, .{ .key = key, .value = value });
        try self.writeAll(allocator, list.items);
    }

    fn delete(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void {
        const self: *PostgresStore = @ptrCast(@alignCast(ptr));
        const entries = try self.readAll(allocator);
        defer freeEntries(allocator, entries);
        var list: std.ArrayList(Entry) = .empty;
        defer list.deinit(allocator);
        for (entries) |e| {
            if (!std.mem.eql(u8, e.key, key)) try list.append(allocator, e);
        }
        try self.writeAll(allocator, list.items);
    }

    fn listKeys(ptr: *anyopaque, allocator: std.mem.Allocator, prefix: []const u8) anyerror![]const []const u8 {
        const self: *PostgresStore = @ptrCast(@alignCast(ptr));
        const entries = try self.readAll(allocator);
        defer freeEntries(allocator, entries);
        var list: std.ArrayList([]const u8) = .empty;
        for (entries) |e| {
            if (prefix.len == 0 or std.mem.startsWith(u8, e.key, prefix)) {
                try list.append(allocator, try allocator.dupe(u8, e.key));
            }
        }
        return try list.toOwnedSlice(allocator);
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

test "postgres store put and get" {
    const dir = "_zig_proxy_pg_store_test";
    std.fs.cwd().deleteTree(dir) catch {};
    defer std.fs.cwd().deleteTree(dir) catch {};
    var ps = PostgresStore.init(std.testing.allocator, dir);
    var b = ps.backend();
    try b.put(std.testing.allocator, "key1", "value1");
    const val = try b.get(std.testing.allocator, "key1");
    try std.testing.expect(val != null);
    defer std.testing.allocator.free(val.?);
    try std.testing.expectEqualStrings("value1", val.?);
}
