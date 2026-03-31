const std = @import("std");

pub const Strategy = enum {
    round_robin,
    fill_first,

    pub fn name(self: Strategy) []const u8 {
        return switch (self) {
            .round_robin => "round-robin",
            .fill_first => "fill-first",
        };
    }
};

pub const Credential = struct {
    id: []const u8 = "",
    provider: []const u8 = "",
    prefix: []const u8 = "",
    priority: u8 = 0,
    cooled_until: i64 = 0,
    disabled: bool = false,

    pub fn isAvailable(self: *const Credential) bool {
        if (self.disabled) return false;
        if (self.cooled_until == 0) return true;
        return std.time.timestamp() >= self.cooled_until;
    }
};

pub const SelectionResult = struct {
    credential: ?*Credential = null,
    index: usize = 0,
};

test "strategy names" {
    try std.testing.expectEqualStrings("round-robin", Strategy.round_robin.name());
    try std.testing.expectEqualStrings("fill-first", Strategy.fill_first.name());
}

test "credential availability - default is available" {
    const cred = Credential{};
    try std.testing.expect(cred.isAvailable());
}

test "credential availability - disabled" {
    const cred = Credential{ .disabled = true };
    try std.testing.expect(!cred.isAvailable());
}

test "credential availability - cooled in future" {
    const cred = Credential{ .cooled_until = std.time.timestamp() + 9999 };
    try std.testing.expect(!cred.isAvailable());
}

test "credential availability - cooled in past" {
    const cred = Credential{ .cooled_until = 1 };
    try std.testing.expect(cred.isAvailable());
}
