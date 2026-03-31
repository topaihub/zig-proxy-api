const std = @import("std");
const auth_types = @import("../types.zig");

pub const ClaudeAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ClaudeAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "claude";
    }

    pub fn login(self: *ClaudeAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "claude", .id = "claude-stub" };
    }

    pub fn deinit(self: *ClaudeAuth) void {
        _ = self;
    }
};
