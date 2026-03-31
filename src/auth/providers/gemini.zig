const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const GeminiAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "gemini-cli",
    auth_url: []const u8 = "https://accounts.google.com/o/oauth2/v2/auth",
    token_url: []const u8 = "https://oauth2.googleapis.com/token",
    scope: []const u8 = "https://www.googleapis.com/auth/generative-language",
    callback_port: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) GeminiAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "gemini";
    }

    pub fn buildAuthUrl(self: *const GeminiAuth, allocator: std.mem.Allocator, state: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator,
            "{s}?response_type=code&client_id={s}&scope={s}&state={s}&redirect_uri=http://localhost:{d}/google/callback",
            .{ self.auth_url, self.client_id, self.scope, state, self.callback_port },
        );
    }

    pub fn exchangeCode(self: *const GeminiAuth, allocator: std.mem.Allocator, code: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=authorization_code&code={s}&client_id={s}&redirect_uri=http://localhost:{d}/google/callback",
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

        return .{ .provider = "gemini", .id = "gemini-oauth", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *GeminiAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "gemini", .id = "gemini-stub" };
    }

    pub fn deinit(self: *GeminiAuth) void {
        _ = self;
    }
};

test "gemini builds auth url" {
    const auth = GeminiAuth{ .allocator = std.testing.allocator, .callback_port = 9090 };
    const url = try auth.buildAuthUrl(std.testing.allocator, "mystate");
    defer std.testing.allocator.free(url);
    try std.testing.expect(std.mem.indexOf(u8, url, "generative-language") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "state=mystate") != null);
}
