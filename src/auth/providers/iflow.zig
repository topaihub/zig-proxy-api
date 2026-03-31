const std = @import("std");
const auth_types = @import("../types.zig");

pub const IflowAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IflowAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "iflow";
    }

    pub fn login(self: *IflowAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "iflow", .id = "iflow-stub" };
    }

    pub fn deinit(self: *IflowAuth) void {
        _ = self;
    }
};
