const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const DeviceCodeResponse = struct {
    device_code: []const u8 = "",
    user_code: []const u8 = "",
    verification_uri: []const u8 = "",
    interval: u16 = 5,
};

pub const CodexAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "codex-cli",
    device_auth_url: []const u8 = "https://auth.openai.com/oauth/device/code",
    token_url: []const u8 = "https://auth.openai.com/oauth/token",

    pub fn init(allocator: std.mem.Allocator) CodexAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "codex";
    }

    /// Request a device code for the device authorization flow
    pub fn requestDeviceCode(self: *const CodexAuth, allocator: std.mem.Allocator) !DeviceCodeResponse {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator, "client_id={s}&scope=openai", .{self.client_id});
        defer allocator.free(body);

        var resp = try http_client.send(allocator, .{
            .method = .POST,
            .url = self.device_auth_url,
            .headers = &.{.{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" }},
            .body = body,
        });
        defer resp.deinit(allocator);

        // In a real implementation, parse JSON response for device_code, user_code, etc.
        return .{
            .device_code = "pending",
            .user_code = "pending",
            .verification_uri = "https://auth.openai.com/activate",
        };
    }

    /// Poll the token endpoint until the user completes authorization
    pub fn pollForToken(self: *const CodexAuth, allocator: std.mem.Allocator, device_code: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code={s}&client_id={s}",
            .{ device_code, self.client_id },
        );
        defer allocator.free(body);

        var resp = try http_client.send(allocator, .{
            .method = .POST,
            .url = self.token_url,
            .headers = &.{.{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" }},
            .body = body,
        });
        defer resp.deinit(allocator);

        return .{ .provider = "codex", .id = "codex-device", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *CodexAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "codex", .id = "codex-stub" };
    }

    pub fn deinit(self: *CodexAuth) void {
        _ = self;
    }
};

test "codex provider name" {
    try std.testing.expectEqualStrings("codex", CodexAuth.provider());
}
