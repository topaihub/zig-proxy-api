const std = @import("std");
const auth_types = @import("../types.zig");

pub const VertexAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VertexAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "vertex";
    }

    pub fn login(self: *VertexAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "vertex", .id = "vertex-stub" };
    }

    pub fn deinit(self: *VertexAuth) void {
        _ = self;
    }
};
