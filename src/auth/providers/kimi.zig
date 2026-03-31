const std = @import("std");
const auth_types = @import("../types.zig");

pub const KimiAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) KimiAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "kimi";
    }

    pub fn login(self: *KimiAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "kimi", .id = "kimi-stub" };
    }

    pub fn deinit(self: *KimiAuth) void {
        _ = self;
    }
};
