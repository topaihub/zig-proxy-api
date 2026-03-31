const std = @import("std");
const types = @import("types.zig");
const Format = types.Format;
const RequestTransform = types.RequestTransform;
const ResponseTransform = types.ResponseTransform;

const N = @typeInfo(Format).@"enum".fields.len;

pub const Registry = struct {
    allocator: std.mem.Allocator,
    requests: [N][N]?RequestTransform = .{.{null} ** N} ** N,
    responses: [N][N]ResponseTransform = .{.{ResponseTransform{}} ** N} ** N,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn register(self: *Registry, from: Format, to: Format, req: ?RequestTransform, resp: ResponseTransform) void {
        const f = @intFromEnum(from);
        const t = @intFromEnum(to);
        self.requests[f][t] = req;
        self.responses[f][t] = resp;
    }

    pub fn translateRequest(self: *const Registry, from: Format, to: Format, model: []const u8, raw_json: []const u8, stream: bool) []const u8 {
        if (self.requests[@intFromEnum(from)][@intFromEnum(to)]) |transform| {
            return transform(model, raw_json, stream);
        }
        return raw_json;
    }

    pub fn hasResponseTransform(self: *const Registry, from: Format, to: Format) bool {
        const resp = self.responses[@intFromEnum(from)][@intFromEnum(to)];
        return resp.stream != null or resp.non_stream != null;
    }

    pub fn deinit(self: *Registry) void {
        _ = self;
    }

    pub fn count(self: *const Registry) usize {
        var c: usize = 0;
        for (self.requests) |row| {
            for (row) |cell| {
                if (cell != null) c += 1;
            }
        }
        return c;
    }
};

test "registry stores and retrieves transforms" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();

    const transform = struct {
        fn t(_: []const u8, _: []const u8, _: bool) []const u8 {
            return "translated";
        }
    }.t;

    reg.register(.openai, .claude, transform, .{});
    const result = reg.translateRequest(.openai, .claude, "model", "original", false);
    try std.testing.expectEqualStrings("translated", result);
}

test "registry returns original when no transform" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    const result = reg.translateRequest(.openai, .gemini, "model", "original", false);
    try std.testing.expectEqualStrings("original", result);
}
