const std = @import("std");

pub const TlsConfig = struct {
    cert_path: []const u8 = "",
    key_path: []const u8 = "",
    enabled: bool = false,

    pub fn isConfigured(self: *const TlsConfig) bool {
        return self.enabled and self.cert_path.len > 0 and self.key_path.len > 0;
    }
};

pub const CertData = struct {
    cert: []u8,
    key: []u8,

    pub fn deinit(self: *CertData, allocator: std.mem.Allocator) void {
        allocator.free(self.cert);
        allocator.free(self.key);
    }
};

pub fn loadCertificates(allocator: std.mem.Allocator, config: TlsConfig) !?CertData {
    if (!config.isConfigured()) return null;
    const cert = try std.fs.cwd().readFileAlloc(allocator, config.cert_path, 1024 * 1024);
    errdefer allocator.free(cert);
    const key = try std.fs.cwd().readFileAlloc(allocator, config.key_path, 1024 * 1024);
    return .{ .cert = cert, .key = key };
}

test "tls config not configured by default" {
    const cfg = TlsConfig{};
    try std.testing.expect(!cfg.isConfigured());
}

test "tls config configured when all set" {
    const cfg = TlsConfig{ .cert_path = "_test_cert.pem", .key_path = "_test_key.pem", .enabled = true };
    try std.testing.expect(cfg.isConfigured());
}

test "load certificates returns null when not configured" {
    const result = try loadCertificates(std.testing.allocator, .{});
    try std.testing.expect(result == null);
}
