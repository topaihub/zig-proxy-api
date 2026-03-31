const std = @import("std");

pub const Auth = struct {
    id: []const u8 = "",
    provider: []const u8 = "",
    prefix: []const u8 = "",
    label: []const u8 = "",
    token: []const u8 = "",
    refresh_token: []const u8 = "",
    expires_at: []const u8 = "",
    disabled: []const u8 = "",
    file_name: []const u8 = "",
    priority: []const u8 = "",
    base_url: []const u8 = "",
    proxy_url: []const u8 = "",
};

pub const Store = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        list: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]Auth,
        save: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, auth: *const Auth) anyerror!void,
        delete: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) anyerror!void,
    };

    pub fn list(self: Store, allocator: std.mem.Allocator) ![]Auth {
        return self.vtable.list(self.ptr, allocator);
    }

    pub fn save(self: Store, allocator: std.mem.Allocator, auth: *const Auth) !void {
        return self.vtable.save(self.ptr, allocator, auth);
    }

    pub fn delete(self: Store, allocator: std.mem.Allocator, id: []const u8) !void {
        return self.vtable.delete(self.ptr, allocator, id);
    }
};

test "auth default values" {
    const auth = Auth{};
    try std.testing.expectEqualStrings("", auth.id);
    try std.testing.expectEqualStrings("", auth.token);
}
