const std = @import("std");
const framework = @import("framework");
const auth_types = @import("../types.zig");

pub const VertexAuth = struct {
    allocator: std.mem.Allocator,
    client_id: []const u8 = "vertex-cli",
    auth_url: []const u8 = "https://accounts.google.com/o/oauth2/v2/auth",
    token_url: []const u8 = "https://oauth2.googleapis.com/token",
    scope: []const u8 = "https://www.googleapis.com/auth/cloud-platform",
    callback_port: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) VertexAuth {
        return .{ .allocator = allocator };
    }

    pub fn provider() []const u8 {
        return "vertex";
    }

    pub fn buildAuthUrl(self: *const VertexAuth, allocator: std.mem.Allocator, state: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator,
            "{s}?response_type=code&client_id={s}&scope={s}&state={s}&redirect_uri=http://localhost:{d}/vertex/callback",
            .{ self.auth_url, self.client_id, self.scope, state, self.callback_port },
        );
    }

    pub fn exchangeCode(self: *const VertexAuth, allocator: std.mem.Allocator, code: []const u8) !auth_types.Auth {
        var http_client = framework.NativeHttpClient.init(null);
        const body = try std.fmt.allocPrint(allocator,
            "grant_type=authorization_code&code={s}&client_id={s}&redirect_uri=http://localhost:{d}/vertex/callback",
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

        return .{ .provider = "vertex", .id = "vertex-oauth", .token = try allocator.dupe(u8, resp.body) };
    }

    pub fn login(self: *VertexAuth) !auth_types.Auth {
        _ = self;
        return .{ .provider = "vertex", .id = "vertex-stub" };
    }

    pub fn deinit(self: *VertexAuth) void {
        _ = self;
    }
};
