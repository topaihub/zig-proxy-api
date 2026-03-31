const std = @import("std");
const auth_types = @import("../types.zig");

pub const AntigravityAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AntigravityAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "antigravity";
    }

    pub fn login(self: *AntigravityAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "antigravity", .id = "antigravity-stub" };
    }

    pub fn deinit(self: *AntigravityAuth) void {
        _ = self;
    }
};
