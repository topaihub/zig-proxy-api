const std = @import("std");
const types = @import("types.zig");

pub const Manager = struct {
    store: ?types.Store = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Manager {
        return .{ .allocator = allocator };
    }

    pub fn setStore(self: *Manager, store: types.Store) void {
        self.store = store;
    }

    pub fn listAll(self: *Manager) ![]types.Auth {
        const s = self.store orelse return &.{};
        return s.list(self.allocator);
    }

    pub fn deinit(self: *Manager) void {
        _ = self;
    }
};

test "manager init and list without store returns empty" {
    var mgr = Manager.init(std.testing.allocator);
    defer mgr.deinit();
    const list = try mgr.listAll();
    try std.testing.expectEqual(@as(usize, 0), list.len);
}
