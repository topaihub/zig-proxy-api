const std = @import("std");
const types = @import("types.zig");
const Strategy = types.Strategy;
const Credential = types.Credential;

pub const Selector = struct {
    strategy: Strategy = .round_robin,
    credentials: []Credential = &.{},
    rr_index: usize = 0,

    pub fn init(strategy: Strategy) Selector {
        return .{ .strategy = strategy };
    }

    pub fn setCredentials(self: *Selector, creds: []Credential) void {
        self.credentials = creds;
    }

    pub fn select(self: *Selector, provider: []const u8) ?*Credential {
        return switch (self.strategy) {
            .round_robin => self.selectRoundRobin(provider),
            .fill_first => self.selectFillFirst(provider),
        };
    }

    fn selectRoundRobin(self: *Selector, provider: []const u8) ?*Credential {
        const len = self.credentials.len;
        if (len == 0) return null;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const idx = (self.rr_index + i) % len;
            const cred = &self.credentials[idx];
            if (std.mem.eql(u8, cred.provider, provider) and cred.isAvailable()) {
                self.rr_index = (idx + 1) % len;
                return cred;
            }
        }
        return null;
    }

    fn selectFillFirst(self: *Selector, provider: []const u8) ?*Credential {
        var best: ?*Credential = null;
        for (self.credentials) |*cred| {
            if (!std.mem.eql(u8, cred.provider, provider) or !cred.isAvailable()) continue;
            if (best == null or cred.priority > best.?.priority) best = cred;
        }
        return best;
    }
};

test "round-robin rotates through credentials" {
    var creds = [_]Credential{
        .{ .id = "a", .provider = "openai" },
        .{ .id = "b", .provider = "openai" },
        .{ .id = "c", .provider = "openai" },
    };
    var sel = Selector.init(.round_robin);
    sel.setCredentials(&creds);

    try std.testing.expectEqualStrings("a", sel.select("openai").?.id);
    try std.testing.expectEqualStrings("b", sel.select("openai").?.id);
    try std.testing.expectEqualStrings("c", sel.select("openai").?.id);
    try std.testing.expectEqualStrings("a", sel.select("openai").?.id);
}

test "fill-first picks highest priority" {
    var creds = [_]Credential{
        .{ .id = "low", .provider = "openai", .priority = 1 },
        .{ .id = "high", .provider = "openai", .priority = 10 },
        .{ .id = "mid", .provider = "openai", .priority = 5 },
    };
    var sel = Selector.init(.fill_first);
    sel.setCredentials(&creds);

    try std.testing.expectEqualStrings("high", sel.select("openai").?.id);
}

test "skips cooled and disabled credentials" {
    var creds = [_]Credential{
        .{ .id = "disabled", .provider = "openai", .disabled = true },
        .{ .id = "cooled", .provider = "openai", .cooled_until = std.time.timestamp() + 9999 },
        .{ .id = "ok", .provider = "openai" },
    };
    var sel = Selector.init(.round_robin);
    sel.setCredentials(&creds);

    try std.testing.expectEqualStrings("ok", sel.select("openai").?.id);
}

test "returns null when no match" {
    var sel = Selector.init(.round_robin);
    try std.testing.expect(sel.select("openai") == null);
}

test "filters by provider" {
    var creds = [_]Credential{
        .{ .id = "a", .provider = "anthropic" },
        .{ .id = "b", .provider = "openai" },
    };
    var sel = Selector.init(.round_robin);
    sel.setCredentials(&creds);

    try std.testing.expectEqualStrings("b", sel.select("openai").?.id);
}
