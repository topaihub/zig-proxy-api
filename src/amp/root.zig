pub const types = @import("types.zig");
pub const AmpConfig = types.AmpConfig;
pub const ModelMapping = types.ModelMapping;

pub const router_mod = @import("router.zig");
pub const AmpRouter = router_mod.AmpRouter;

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
