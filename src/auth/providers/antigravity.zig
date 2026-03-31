const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const AntigravityAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "antigravity-cli",
    auth_url: []const u8 = "https://auth.antigravity.dev/oauth/authorize",
    token_url: []const u8 = "https://auth.antigravity.dev/oauth/token",
    callback_port: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) AntigravityAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "antigravity";
    }

    pub fn buildAuthUrl(self: *const AntigravityAuth, allocator: std.mem.Allocator, state: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator,
            "{s}?response_type=code&client_id={s}&state={s}&redirect_uri=http://localhost:{d}/antigravity/callback",
            .{ self.auth_url, self.client_id, state, self.callback_port },
        );
    }

    pub fn exchangeCode(self: *const AntigravityAuth, allocator: std.mem.Allocator, code: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=authorization_code&code={s}&client_id={s}&redirect_uri=http://localhost:{d}/antigravity/callback",
            .{ code, self.client_id, self.callback_port },
        );
        defer allocator.free(body);

        var resp = try http_client.send(allocator, .{
            .method = .POST,
            .url = self.token_url,
            .headers = &.{.{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" }},
            .body = body,
        });
        defer resp.deinit(allocator);

        return .{ .provider = "antigravity", .id = "antigravity-oauth", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *AntigravityAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "antigravity", .id = "antigravity-stub" };
    }

    pub fn deinit(self: *AntigravityAuth) void {
        _ = self;
    }
};
