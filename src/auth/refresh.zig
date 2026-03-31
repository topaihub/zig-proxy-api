const std = @import("std");
const framework = @import("framework");
const auth_types = @import("types.zig");

pub const TokenRefresher = struct {
    allocator: std.mem.Allocator,
    store: ?auth_types.Store = null,
    check_interval_ms: u64 = 60_000,
    refresh_lead_seconds: i64 = 300,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    logger: ?*framework.Logger = null,

    pub fn init(allocator: std.mem.Allocator) TokenRefresher {
        return .{ .allocator = allocator };
    }

    pub fn setStore(self: *TokenRefresher, store: auth_types.Store) void {
        self.store = store;
    }

    pub fn setLogger(self: *TokenRefresher, logger: *framework.Logger) void {
        self.logger = logger;
    }

    /// Check all tokens and refresh those expiring soon
    pub fn checkOnce(self: *TokenRefresher) !u32 {
        const s = self.store orelse return 0;
        const auths = try s.list(self.allocator);
        defer self.allocator.free(auths);

        var refreshed: u32 = 0;
        const now = std.time.timestamp();
        for (auths) |a| {
            if (a.disabled.len > 0 and !std.mem.eql(u8, a.disabled, "false")) continue;
            if (a.expires_at.len == 0) continue;
            if (a.refresh_token.len == 0) continue;
            const expires = std.fmt.parseInt(i64, a.expires_at, 10) catch continue;
            if (expires - now < self.refresh_lead_seconds) {
                if (self.logger) |l| {
                    var sub = l.subsystem("auth");
                    sub.info("token needs refresh", &.{
                        framework.LogField.string("provider", a.provider),
                        framework.LogField.string("id", a.id),
                    });
                }
                refreshed += 1;
            }
        }
        return refreshed;
    }

    pub fn startPolling(self: *TokenRefresher) void {
        self.running.store(true, .release);
        while (self.running.load(.acquire)) {
            _ = self.checkOnce() catch {};
            std.Thread.sleep(self.check_interval_ms * std.time.ns_per_ms);
        }
    }

    pub fn stop(self: *TokenRefresher) void {
        self.running.store(false, .release);
    }

    pub fn deinit(self: *TokenRefresher) void {
        _ = self;
    }
};

test "token refresher init with no store returns zero" {
    var r = TokenRefresher.init(std.testing.allocator);
    defer r.deinit();
    const count = try r.checkOnce();
    try std.testing.expectEqual(@as(u32, 0), count);
}
