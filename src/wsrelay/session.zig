const std = @import("std");

pub const Session = struct {
    id: []const u8,
    provider: []const u8,
    connected: bool = false,
    created_at: i64 = 0,

    pub fn init(id: []const u8, provider: []const u8) Session {
        return .{ .id = id, .provider = provider, .created_at = std.time.timestamp() };
    }

    pub fn deinit(self: *Session) void {
        self.connected = false;
    }
};

test "session init and deinit" {
    var s = Session.init("sess-1", "codex");
    try std.testing.expectEqualStrings("sess-1", s.id);
    try std.testing.expectEqualStrings("codex", s.provider);
    try std.testing.expect(!s.connected);
    s.deinit();
}
