const std = @import("std");
const types = @import("types.zig");
const Executor = types.Executor;
const Request = types.Request;
const Response = types.Response;
const Options = types.Options;

pub const ExecutorRegistry = struct {
    allocator: std.mem.Allocator,
    entries: [16]?Entry = .{null} ** 16,
    count: u8 = 0,

    const Entry = struct { provider: []const u8, executor: Executor };

    pub fn init(allocator: std.mem.Allocator) ExecutorRegistry {
        return .{ .allocator = allocator };
    }

    pub fn register(self: *ExecutorRegistry, provider: []const u8, executor: Executor) void {
        if (self.count < 16) {
            self.entries[self.count] = .{ .provider = provider, .executor = executor };
            self.count += 1;
        }
    }

    pub fn find(self: *const ExecutorRegistry, provider: []const u8) ?Executor {
        for (self.entries[0..self.count]) |entry| {
            if (entry) |e| {
                if (std.mem.eql(u8, e.provider, provider)) return e.executor;
            }
        }
        return null;
    }

    pub fn deinit(self: *ExecutorRegistry) void {
        _ = self;
    }
};

const MockExecutor = struct {
    fn executor(self: *MockExecutor) Executor {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }
    const vtable = Executor.VTable{
        .execute = mockExecute,
        .provider_name = mockName,
    };
    fn mockExecute(_: *anyopaque, _: std.mem.Allocator, _: Request, _: Options) anyerror!Response {
        return .{ .status_code = 200, .payload = "{\"ok\":true}" };
    }
    fn mockName(_: *anyopaque) []const u8 {
        return "mock";
    }
};

test "executor registry register and find" {
    var reg = ExecutorRegistry.init(std.testing.allocator);
    defer reg.deinit();

    var mock = MockExecutor{};
    reg.register("gemini", mock.executor());
    const found = reg.find("gemini");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("mock", found.?.providerName());
    try std.testing.expect(reg.find("unknown") == null);
}
