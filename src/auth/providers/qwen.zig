const std = @import("std");
const auth_types = @import("../types.zig");

pub const QwenAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QwenAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "qwen";
    }

    pub fn login(self: *QwenAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "qwen", .id = "qwen-stub" };
    }

    pub fn deinit(self: *QwenAuth) void {
        _ = self;
    }
};
