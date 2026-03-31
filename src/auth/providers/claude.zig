const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const ClaudeAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "claude-cli",
    auth_url: []const u8 = "https://console.anthropic.com/oauth/authorize",
    token_url: []const u8 = "https://console.anthropic.com/oauth/token",
    callback_port: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) ClaudeAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "claude";
    }

    /// Generate PKCE code verifier (43 chars, base64url-encoded random bytes)
    pub fn generateCodeVerifier(buf: *[128]u8) []const u8 {
        std.crypto.random.bytes(buf[0..32]);
        return std.base64.url_safe_no_pad.Encoder.encode(buf[64..107], buf[0..32]);
    }

    /// Generate PKCE code challenge (SHA256 of verifier, base64url-encoded)
    pub fn generateCodeChallenge(verifier: []const u8, buf: *[64]u8) []const u8 {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(verifier, &hash, .{});
        return std.base64.url_safe_no_pad.Encoder.encode(buf[0..43], &hash);
    }

    /// Build authorization URL
    pub fn buildAuthUrl(self: *const ClaudeAuth, allocator: std.mem.Allocator, code_challenge: []const u8, state: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator,
            "{s}?response_type=code&client_id={s}&code_challenge={s}&code_challenge_method=S256&state={s}&redirect_uri=http://localhost:{d}/anthropic/callback",
            .{ self.auth_url, self.client_id, code_challenge, state, self.callback_port },
        );
    }

    /// Exchange authorization code for token via POST to token endpoint
    pub fn exchangeCode(self: *const ClaudeAuth, allocator: std.mem.Allocator, code: []const u8, code_verifier: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=authorization_code&code={s}&code_verifier={s}&client_id={s}&redirect_uri=http://localhost:{d}/anthropic/callback",
            .{ code, code_verifier, self.client_id, self.callback_port },
        );
        defer allocator.free(body);

        var resp = try http_client.send(allocator, .{
            .method = .POST,
            .url = self.token_url,
            .headers = &.{.{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" }},
            .body = body,
        });
        defer resp.deinit(allocator);

        return .{ .provider = "claude", .id = "claude-oauth", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *ClaudeAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "claude", .id = "claude-stub" };
    }

    pub fn deinit(self: *ClaudeAuth) void {
        _ = self;
    }
};

test "claude pkce generates valid verifier" {
    var buf: [128]u8 = undefined;
    const verifier = ClaudeAuth.generateCodeVerifier(&buf);
    try std.testing.expect(verifier.len >= 43);
}

test "claude pkce generates valid challenge" {
    var buf: [64]u8 = undefined;
    const challenge = ClaudeAuth.generateCodeChallenge("test-verifier", &buf);
    try std.testing.expect(challenge.len > 0);
}

test "claude builds auth url" {
    const auth = ClaudeAuth{ .allocator = std.testing.allocator, .callback_port = 8080 };
    const url = try auth.buildAuthUrl(std.testing.allocator, "challenge123", "state456");
    defer std.testing.allocator.free(url);
    try std.testing.expect(std.mem.indexOf(u8, url, "code_challenge=challenge123") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "state=state456") != null);
}
