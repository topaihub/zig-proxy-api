const std = @import("std");
const server = @import("../server/root.zig");
const AmpConfig = @import("types.zig").AmpConfig;

pub const AmpRouter = struct {
    config: AmpConfig = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AmpRouter {
        return .{ .allocator = allocator };
    }

    pub fn resolveModel(self: *const AmpRouter, model: []const u8) []const u8 {
        for (self.config.model_mappings) |m| {
            if (std.mem.eql(u8, m.from, model)) return m.to;
        }
        return model;
    }

    pub fn registerRoutes(self: *AmpRouter, router: *server.Router) void {
        _ = self;
        router.get("/api/provider/:provider/v1/models", handleModels);
        router.post("/api/provider/:provider/v1/chat/completions", handleChat);
    }

    pub fn deinit(self: *AmpRouter) void {
        _ = self;
    }

    fn handleModels(ctx: *server.Context) anyerror!void {
        try ctx.json(.ok, .{ .object = "list", .data = &[_]u8{} });
    }

    fn handleChat(ctx: *server.Context) anyerror!void {
        try ctx.json(.ok, .{ .object = "chat.completion" });
    }
};

test "amp router resolve model with mapping" {
    const mappings = [_]@import("types.zig").ModelMapping{
        .{ .from = "gpt-4", .to = "claude-sonnet-4" },
    };
    var r = AmpRouter.init(std.testing.allocator);
    r.config.model_mappings = &mappings;
    defer r.deinit();

    try std.testing.expectEqualStrings("claude-sonnet-4", r.resolveModel("gpt-4"));
    try std.testing.expectEqualStrings("unknown", r.resolveModel("unknown"));
}
