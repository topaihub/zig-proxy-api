pub const ModelMapping = struct {
    from: []const u8 = "",
    to: []const u8 = "",
};

pub const AmpConfig = struct {
    upstream_url: []const u8 = "https://ampcode.com",
    upstream_api_key: []const u8 = "",
    restrict_management_to_localhost: bool = false,
    force_model_mappings: bool = false,
    model_mappings: []const ModelMapping = &.{},
};

test "amp config defaults" {
    const std = @import("std");
    const cfg = AmpConfig{};
    try std.testing.expectEqualStrings("https://ampcode.com", cfg.upstream_url);
    try std.testing.expect(!cfg.force_model_mappings);
    try std.testing.expectEqual(@as(usize, 0), cfg.model_mappings.len);
}
