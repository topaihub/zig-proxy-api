const std = @import("std");

pub const StoreBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        get: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8,
        put: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, value: []const u8) anyerror!void,
        delete: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void,
        list_keys: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, prefix: []const u8) anyerror![]const []const u8,
        name: *const fn (ptr: *anyopaque) []const u8,
    };

    pub fn get(self: StoreBackend, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        return self.vtable.get(self.ptr, allocator, key);
    }

    pub fn put(self: StoreBackend, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        return self.vtable.put(self.ptr, allocator, key, value);
    }

    pub fn delete(self: StoreBackend, allocator: std.mem.Allocator, key: []const u8) !void {
        return self.vtable.delete(self.ptr, allocator, key);
    }

    pub fn listKeys(self: StoreBackend, allocator: std.mem.Allocator, prefix: []const u8) ![]const []const u8 {
        return self.vtable.list_keys(self.ptr, allocator, prefix);
    }

    pub fn backendName(self: StoreBackend) []const u8 {
        return self.vtable.name(self.ptr);
    }
};
