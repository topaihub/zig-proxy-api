pub const ansi = @import("ansi.zig");
pub const tabs = @import("tabs.zig");
pub const Tab = tabs.Tab;

pub const app = @import("app.zig");
pub const App = app.App;

pub const dashboard = @import("dashboard.zig");
pub const auth_tab = @import("auth_tab.zig");
pub const config_tab = @import("config_tab.zig");
pub const logs_tab = @import("logs_tab.zig");
pub const usage_tab = @import("usage_tab.zig");
pub const oauth_tab = @import("oauth_tab.zig");
pub const keys_tab = @import("keys_tab.zig");

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
