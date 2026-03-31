const std = @import("std");

pub const Language = enum {
    en,
    cn,
    ja,

    pub fn label(self: Language) []const u8 {
        return switch (self) {
            .en => "English",
            .cn => "中文",
            .ja => "日本語",
        };
    }
};

pub const Strings = struct {
    dashboard: []const u8,
    auth: []const u8,
    config: []const u8,
    logs: []const u8,
    usage: []const u8,
    oauth: []const u8,
    keys: []const u8,
    status_running: []const u8,
    status_stopped: []const u8,
    no_auth_records: []const u8,
    no_log_entries: []const u8,
    press_q_to_quit: []const u8,
    press_r_to_reload: []const u8,
};

pub fn get(lang: Language) Strings {
    return switch (lang) {
        .en => .{
            .dashboard = "Dashboard",
            .auth = "Authentication",
            .config = "Configuration",
            .logs = "Logs",
            .usage = "Usage Statistics",
            .oauth = "OAuth",
            .keys = "API Keys",
            .status_running = "Running",
            .status_stopped = "Stopped",
            .no_auth_records = "No auth records loaded.",
            .no_log_entries = "No log entries.",
            .press_q_to_quit = "Press 'q' to quit",
            .press_r_to_reload = "Press 'r' to reload configuration",
        },
        .cn => .{
            .dashboard = "仪表盘",
            .auth = "认证管理",
            .config = "配置",
            .logs = "日志",
            .usage = "使用统计",
            .oauth = "OAuth 登录",
            .keys = "API 密钥",
            .status_running = "运行中",
            .status_stopped = "已停止",
            .no_auth_records = "未加载认证记录。",
            .no_log_entries = "暂无日志。",
            .press_q_to_quit = "按 'q' 退出",
            .press_r_to_reload = "按 'r' 重新加载配置",
        },
        .ja => .{
            .dashboard = "ダッシュボード",
            .auth = "認証",
            .config = "設定",
            .logs = "ログ",
            .usage = "使用統計",
            .oauth = "OAuth",
            .keys = "APIキー",
            .status_running = "実行中",
            .status_stopped = "停止",
            .no_auth_records = "認証レコードがありません。",
            .no_log_entries = "ログエントリがありません。",
            .press_q_to_quit = "'q'で終了",
            .press_r_to_reload = "'r'で設定を再読み込み",
        },
    };
}

test "i18n returns strings for all languages" {
    for ([_]Language{ .en, .cn, .ja }) |lang| {
        const s = get(lang);
        try std.testing.expect(s.dashboard.len > 0);
        try std.testing.expect(s.press_q_to_quit.len > 0);
    }
}
