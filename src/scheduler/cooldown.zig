const std = @import("std");
const Credential = @import("types.zig").Credential;

pub const CooldownManager = struct {
    default_seconds: u16 = 30,

    pub fn cool(self: *const CooldownManager, cred: *Credential) void {
        cred.cooled_until = std.time.timestamp() + @as(i64, self.default_seconds);
    }

    pub fn reset(cred: *Credential) void {
        cred.cooled_until = 0;
    }
};

test "cool sets future timestamp" {
    var cred = Credential{};
    const mgr = CooldownManager{ .default_seconds = 60 };
    mgr.cool(&cred);
    try std.testing.expect(cred.cooled_until > std.time.timestamp());
    try std.testing.expect(!cred.isAvailable());
}

test "reset clears cooldown" {
    var cred = Credential{ .cooled_until = std.time.timestamp() + 9999 };
    CooldownManager.reset(&cred);
    try std.testing.expectEqual(@as(i64, 0), cred.cooled_until);
    try std.testing.expect(cred.isAvailable());
}
