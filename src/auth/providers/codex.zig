const std = @import("std");
const auth_types = @import("../types.zig");

pub const CodexAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CodexAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "codex";
    }

    pub fn login(self: *CodexAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "codex", .id = "codex-stub" };
    }

    pub fn deinit(self: *CodexAuth) void {
        _ = self;
    }
};
