const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const KimiAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "kimi-cli",
    auth_url: []const u8 = "https://account.moonshot.cn/oauth/authorize",
    token_url: []const u8 = "https://account.moonshot.cn/oauth/token",
    callback_port: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) KimiAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "kimi";
    }

    pub fn buildAuthUrl(self: *const KimiAuth, allocator: std.mem.Allocator, state: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator,
            "{s}?response_type=code&client_id={s}&state={s}&redirect_uri=http://localhost:{d}/kimi/callback",
            .{ self.auth_url, self.client_id, state, self.callback_port },
        );
    }

    pub fn exchangeCode(self: *const KimiAuth, allocator: std.mem.Allocator, code: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=authorization_code&code={s}&client_id={s}&redirect_uri=http://localhost:{d}/kimi/callback",
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

        return .{ .provider = "kimi", .id = "kimi-oauth", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *KimiAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "kimi", .id = "kimi-stub" };
    }

    pub fn deinit(self: *KimiAuth) void {
        _ = self;
    }
};
