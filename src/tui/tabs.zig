pub const Tab = enum {
    dashboard,
    auth,
    config,
    logs,
    usage,
    oauth,
    keys,

    pub fn label(self: Tab) []const u8 {
        return switch (self) {
            .dashboard => "Dashboard",
            .auth => "Auth",
            .config => "Config",
            .logs => "Logs",
            .usage => "Usage",
            .oauth => "OAuth",
            .keys => "Keys",
        };
    }
};

pub const all_tabs = [_]Tab{ .dashboard, .auth, .config, .logs, .usage, .oauth, .keys };

const std = @import("std");

test "all_tabs has 7 entries" {
    try std.testing.expectEqual(@as(usize, 7), all_tabs.len);
}

test "labels are non-empty" {
    for (all_tabs) |tab| {
        try std.testing.expect(tab.label().len > 0);
    }
}
