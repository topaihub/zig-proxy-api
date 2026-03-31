const std = @import("std");
const types = @import("types.zig");
const Auth = types.Auth;
const Store = types.Store;

pub const FileStore = struct {
    base_dir: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_dir: []const u8) FileStore {
        return .{ .allocator = allocator, .base_dir = base_dir };
    }

    pub fn deinit(self: *FileStore) void {
        _ = self;
    }

    pub fn store(self: *FileStore) Store {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .list = typeErasedList,
                .save = typeErasedSave,
                .delete = typeErasedDelete,
            },
        };
    }

    fn typeErasedList(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]Auth {
        const self: *FileStore = @ptrCast(@alignCast(ptr));
        return self.listImpl(allocator);
    }

    fn typeErasedSave(ptr: *anyopaque, allocator: std.mem.Allocator, auth: *const Auth) anyerror!void {
        const self: *FileStore = @ptrCast(@alignCast(ptr));
        return self.saveImpl(allocator, auth);
    }

    fn typeErasedDelete(ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) anyerror!void {
        const self: *FileStore = @ptrCast(@alignCast(ptr));
        return self.deleteImpl(allocator, id);
    }

    fn saveImpl(self: *FileStore, allocator: std.mem.Allocator, auth: *const Auth) !void {
        std.fs.cwd().makePath(self.base_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        const filename = try std.fmt.allocPrint(allocator, "auth-{s}.json", .{auth.id});
        defer allocator.free(filename);

        var dir = try std.fs.cwd().openDir(self.base_dir, .{});
        defer dir.close();

        const json = try std.json.Stringify.valueAlloc(allocator, auth.*, .{});
        defer allocator.free(json);

        try dir.writeFile(.{ .sub_path = filename, .data = json });
    }

    fn listImpl(self: *FileStore, allocator: std.mem.Allocator) ![]Auth {
        var dir = std.fs.cwd().openDir(self.base_dir, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return try allocator.alloc(Auth, 0),
            else => return err,
        };
        defer dir.close();

        var results: std.ArrayList(Auth) = .{};
        errdefer {
            for (results.items) |a| freeAuth(allocator, a);
            results.deinit(allocator);
        }

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, "auth-")) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            const data = try dir.readFileAlloc(allocator, entry.name, 1024 * 1024);
            defer allocator.free(data);

            const parsed = try std.json.parseFromSlice(Auth, allocator, data, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();

            try results.append(allocator, .{
                .id = try allocator.dupe(u8, parsed.value.id),
                .provider = try allocator.dupe(u8, parsed.value.provider),
                .prefix = try allocator.dupe(u8, parsed.value.prefix),
                .label = try allocator.dupe(u8, parsed.value.label),
                .token = try allocator.dupe(u8, parsed.value.token),
                .refresh_token = try allocator.dupe(u8, parsed.value.refresh_token),
                .expires_at = try allocator.dupe(u8, parsed.value.expires_at),
                .disabled = try allocator.dupe(u8, parsed.value.disabled),
                .file_name = try allocator.dupe(u8, parsed.value.file_name),
                .priority = try allocator.dupe(u8, parsed.value.priority),
                .base_url = try allocator.dupe(u8, parsed.value.base_url),
                .proxy_url = try allocator.dupe(u8, parsed.value.proxy_url),
            });
        }

        return results.toOwnedSlice(allocator);
    }

    fn deleteImpl(self: *FileStore, allocator: std.mem.Allocator, id: []const u8) !void {
        const filename = try std.fmt.allocPrint(allocator, "auth-{s}.json", .{id});
        defer allocator.free(filename);

        var dir = try std.fs.cwd().openDir(self.base_dir, .{});
        defer dir.close();

        try dir.deleteFile(filename);
    }
};

fn freeAuth(allocator: std.mem.Allocator, a: Auth) void {
    const fields = [_][]const u8{ a.id, a.provider, a.prefix, a.label, a.token, a.refresh_token, a.expires_at, a.disabled, a.file_name, a.priority, a.base_url, a.proxy_url };
    for (fields) |f| {
        if (f.len > 0) allocator.free(f);
    }
}

fn freeAuthSlice(allocator: std.mem.Allocator, auths: []Auth) void {
    for (auths) |a| freeAuth(allocator, a);
    allocator.free(auths);
}

test "file store save and list" {
    const dir = "/tmp/_zig_proxy_auth_test";
    std.fs.cwd().deleteTree(dir) catch {};
    defer std.fs.cwd().deleteTree(dir) catch {};

    var fs = FileStore.init(std.testing.allocator, dir);
    var s = fs.store();

    const auth = Auth{ .id = "test1", .provider = "gemini", .token = "tok123" };
    try s.save(std.testing.allocator, &auth);

    const list_result = try s.list(std.testing.allocator);
    defer freeAuthSlice(std.testing.allocator, list_result);
    try std.testing.expect(list_result.len >= 1);
    try std.testing.expectEqualStrings("test1", list_result[0].id);
    try std.testing.expectEqualStrings("gemini", list_result[0].provider);
    try std.testing.expectEqualStrings("tok123", list_result[0].token);
}

test "file store delete" {
    const dir = "/tmp/_zig_proxy_auth_test_del";
    std.fs.cwd().deleteTree(dir) catch {};
    defer std.fs.cwd().deleteTree(dir) catch {};

    var fs = FileStore.init(std.testing.allocator, dir);
    var s = fs.store();

    const auth = Auth{ .id = "del1", .provider = "claude", .token = "t" };
    try s.save(std.testing.allocator, &auth);
    try s.delete(std.testing.allocator, "del1");

    const list_result = try s.list(std.testing.allocator);
    defer std.testing.allocator.free(list_result);
    try std.testing.expectEqual(@as(usize, 0), list_result.len);
}
