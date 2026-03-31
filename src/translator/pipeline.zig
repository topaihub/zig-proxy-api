const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const std = @import("std");
const Format = types.Format;
const RequestEnvelope = types.RequestEnvelope;
const Registry = registry_mod.Registry;

pub const Pipeline = struct {
    registry: *Registry,

    pub fn init(reg: *Registry) Pipeline {
        return .{ .registry = reg };
    }

    pub fn translateRequest(self: *const Pipeline, from: Format, to: Format, envelope: RequestEnvelope) RequestEnvelope {
        const body = self.registry.translateRequest(from, to, envelope.model, envelope.body, envelope.stream);
        return .{
            .format = to,
            .model = envelope.model,
            .stream = envelope.stream,
            .body = body,
        };
    }
};

test "pipeline delegates to registry" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    var pipeline = Pipeline.init(&reg);
    const result = pipeline.translateRequest(.openai, .claude, .{ .format = .openai, .body = "test" });
    try std.testing.expectEqualStrings("test", result.body);
}
