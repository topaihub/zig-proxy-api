const std = @import("std");
const auth_types = @import("../types.zig");

pub const GeminiAuth = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GeminiAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "gemini";
    }

    pub fn login(self: *GeminiAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "gemini", .id = "gemini-stub" };
    }

    pub fn deinit(self: *GeminiAuth) void {
        _ = self;
    }
};
