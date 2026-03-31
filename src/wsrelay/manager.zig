const std = @import("std");
const Session = @import("session.zig").Session;

pub const RelayManager = struct {
    allocator: std.mem.Allocator,
    sessions: [32]?Session = .{null} ** 32,
    session_count: u8 = 0,

    pub fn init(allocator: std.mem.Allocator) RelayManager {
        return .{ .allocator = allocator };
    }

    pub fn addSession(self: *RelayManager, session: Session) void {
        for (&self.sessions) |*slot| {
            if (slot.* == null) {
                slot.* = session;
                self.session_count += 1;
                return;
            }
        }
    }

    pub fn removeSession(self: *RelayManager, id: []const u8) void {
        for (&self.sessions) |*slot| {
            if (slot.*) |*s| {
                if (std.mem.eql(u8, s.id, id)) {
                    s.deinit();
                    slot.* = null;
                    self.session_count -= 1;
                    return;
                }
            }
        }
    }

    pub fn findSession(self: *RelayManager, provider: []const u8) ?*Session {
        for (&self.sessions) |*slot| {
            if (slot.*) |*s| {
                if (std.mem.eql(u8, s.provider, provider)) return s;
            }
        }
        return null;
    }

    pub fn deinit(self: *RelayManager) void {
        for (&self.sessions) |*slot| {
            if (slot.*) |*s| {
                s.deinit();
                slot.* = null;
            }
        }
        self.session_count = 0;
    }
};

test "relay manager add/find/remove" {
    var mgr = RelayManager.init(std.testing.allocator);
    defer mgr.deinit();

    mgr.addSession(Session.init("s1", "codex"));
    try std.testing.expectEqual(@as(u8, 1), mgr.session_count);

    const found = mgr.findSession("codex");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("s1", found.?.id);

    mgr.removeSession("s1");
    try std.testing.expectEqual(@as(u8, 0), mgr.session_count);
    try std.testing.expect(mgr.findSession("codex") == null);
}
