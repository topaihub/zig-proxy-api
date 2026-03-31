const std = @import("std");
const tabs = @import("tabs.zig");
const ansi = @import("ansi.zig");
const dashboard = @import("dashboard.zig");
const auth_tab = @import("auth_tab.zig");
const config_tab = @import("config_tab.zig");
const logs_tab = @import("logs_tab.zig");
const usage_tab = @import("usage_tab.zig");
const oauth_tab = @import("oauth_tab.zig");
const keys_tab = @import("keys_tab.zig");

const RawMode = struct {
    original: std.posix.termios,

    pub fn enable() !RawMode {
        const original = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
        var new = original;
        new.lflag.ICANON = false;
        new.lflag.ECHO = false;
        new.cc[@intFromEnum(std.posix.V.MIN)] = 0;
        new.cc[@intFromEnum(std.posix.V.TIME)] = 1;
        try std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, new);
        return .{ .original = original };
    }

    pub fn disable(self: *RawMode) void {
        std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, self.original) catch {};
    }
};

pub const App = struct {
    allocator: std.mem.Allocator,
    current_tab: tabs.Tab = .dashboard,
    running: bool = false,
    stdout: std.fs.File,
    buf: [4096]u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) App {
        return .{
            .allocator = allocator,
            .stdout = std.fs.File.stdout(),
        };
    }

    pub fn handleInput(self: *App, byte: u8) bool {
        switch (byte) {
            'q' => return false,
            '\t' => self.nextTab(),
            'h' => self.prevTab(),
            'l' => self.nextTab(),
            '1'...'7' => |n| self.current_tab = @enumFromInt(n - '1'),
            else => {},
        }
        return true;
    }

    pub fn run(self: *App) !void {
        var raw = RawMode.enable() catch null;
        defer if (raw) |*r| r.disable();

        var writer = self.stdout.writer(&self.buf);
        try writer.writeAll(ansi.hide_cursor);
        try writer.flush();

        self.running = true;
        const stdin = std.fs.File.stdin();

        while (self.running) {
            writer = self.stdout.writer(&self.buf);
            try writer.writeAll(ansi.clear_screen);
            try writer.flush();
            try self.renderTabBar();
            try self.renderCurrentTab();

            var input_buf: [1]u8 = undefined;
            const n = stdin.read(&input_buf) catch 0;
            if (n > 0 and !self.handleInput(input_buf[0])) break;
        }

        writer = self.stdout.writer(&self.buf);
        try writer.writeAll(ansi.show_cursor);
        try writer.flush();
    }

    pub fn nextTab(self: *App) void {
        const idx = @intFromEnum(self.current_tab);
        const count = @typeInfo(tabs.Tab).@"enum".fields.len;
        self.current_tab = @enumFromInt((idx + 1) % count);
    }

    pub fn prevTab(self: *App) void {
        const idx = @intFromEnum(self.current_tab);
        const count = @typeInfo(tabs.Tab).@"enum".fields.len;
        self.current_tab = @enumFromInt(if (idx == 0) count - 1 else idx - 1);
    }

    pub fn renderTabBar(self: *App) !void {
        var writer = self.stdout.writer(&self.buf);
        for (tabs.all_tabs) |tab| {
            if (tab == self.current_tab) {
                try writer.print("{s}{s} {s} {s}", .{ ansi.bg_blue, ansi.white, tab.label(), ansi.reset });
            } else {
                try writer.print(" {s} ", .{tab.label()});
            }
        }
        try writer.writeByte('\n');
        try writer.flush();
    }

    pub fn renderCurrentTab(self: *App) !void {
        var writer = self.stdout.writer(&self.buf);
        switch (self.current_tab) {
            .dashboard => try dashboard.render(&writer),
            .auth => try auth_tab.render(&writer),
            .config => try config_tab.render(&writer),
            .logs => try logs_tab.render(&writer),
            .usage => try usage_tab.render(&writer),
            .oauth => try oauth_tab.render(&writer),
            .keys => try keys_tab.render(&writer),
        }
        try writer.flush();
    }

    pub fn deinit(self: *App) void {
        _ = self;
    }
};

test "app tab navigation wraps around" {
    var app = App.init(std.testing.allocator);
    defer app.deinit();
    try std.testing.expectEqual(tabs.Tab.dashboard, app.current_tab);
    app.nextTab();
    try std.testing.expectEqual(tabs.Tab.auth, app.current_tab);
    // wrap around backward
    app.current_tab = .dashboard;
    app.prevTab();
    try std.testing.expectEqual(tabs.Tab.keys, app.current_tab);
}

test "handle input tab navigation" {
    var app_inst = App.init(std.testing.allocator);
    defer app_inst.deinit();
    try std.testing.expect(app_inst.handleInput('\t'));
    try std.testing.expectEqual(tabs.Tab.auth, app_inst.current_tab);
    try std.testing.expect(app_inst.handleInput('1'));
    try std.testing.expectEqual(tabs.Tab.dashboard, app_inst.current_tab);
    try std.testing.expect(!app_inst.handleInput('q'));
}

test "render current tab does not error" {
    var app_inst = App.init(std.testing.allocator);
    defer app_inst.deinit();
    for (tabs.all_tabs) |tab| {
        app_inst.current_tab = tab;
    }
}