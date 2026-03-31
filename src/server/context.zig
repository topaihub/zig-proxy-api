const std = @import("std");

pub const ParamEntry = struct { key: []const u8, value: []const u8 };
pub const HeaderEntry = struct { name: []const u8, value: []const u8 };
pub const Handler = *const fn (*Context) anyerror!void;

pub const Context = struct {
    allocator: std.mem.Allocator,
    request_method: std.http.Method,
    request_path: []const u8,
    request_body: ?[]const u8 = null,
    params: [8]ParamEntry = undefined,
    param_count: u8 = 0,
    query_string: ?[]const u8 = null,
    response_buf: std.ArrayListUnmanaged(u8) = .empty,
    response_status: std.http.Status = .ok,
    response_headers: [16]HeaderEntry = undefined,
    response_header_count: u8 = 0,
    response_started: bool = false,

    pub fn path(self: *Context) []const u8 {
        return self.request_path;
    }

    pub fn method(self: *Context) std.http.Method {
        return self.request_method;
    }

    pub fn param(self: *Context, key: []const u8) ?[]const u8 {
        for (self.params[0..self.param_count]) |p| {
            if (std.mem.eql(u8, p.key, key)) return p.value;
        }
        return null;
    }

    pub fn setParam(self: *Context, key: []const u8, value: []const u8) void {
        if (self.param_count < 8) {
            self.params[self.param_count] = .{ .key = key, .value = value };
            self.param_count += 1;
        }
    }

    pub fn query(self: *Context, key: []const u8) ?[]const u8 {
        const qs = self.query_string orelse return null;
        var pairs = std.mem.splitScalar(u8, qs, '&');
        while (pairs.next()) |pair| {
            if (std.mem.indexOfScalar(u8, pair, '=')) |eq| {
                if (std.mem.eql(u8, pair[0..eq], key)) return pair[eq + 1 ..];
            }
        }
        return null;
    }

    pub fn header(self: *Context, name: []const u8) ?[]const u8 {
        _ = self;
        _ = name;
        return null;
    }

    pub fn readBody(self: *Context) ?[]const u8 {
        return self.request_body;
    }

    pub fn setStatus(self: *Context, status: std.http.Status) void {
        self.response_status = status;
    }

    pub fn setHeader(self: *Context, name: []const u8, value: []const u8) void {
        if (self.response_header_count < 16) {
            self.response_headers[self.response_header_count] = .{ .name = name, .value = value };
            self.response_header_count += 1;
        }
    }

    pub fn json(self: *Context, status: std.http.Status, value: anytype) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "application/json");
        std.json.stringify(value, .{}, self.response_buf.writer(self.allocator)) catch |err| return err;
        self.response_started = true;
    }

    pub fn text(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "text/plain");
        try self.response_buf.appendSlice(self.allocator, body);
        self.response_started = true;
    }

    pub fn html(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "text/html");
        try self.response_buf.appendSlice(self.allocator, body);
        self.response_started = true;
    }

    pub fn raw(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        try self.response_buf.appendSlice(self.allocator, body);
        self.response_started = true;
    }

    // Test helpers
    pub fn initTest(m: std.http.Method, p: []const u8, allocator: std.mem.Allocator) Context {
        return .{ .allocator = allocator, .request_method = m, .request_path = p };
    }

    pub fn testResponseBody(self: *Context) []const u8 {
        return self.response_buf.items;
    }

    pub fn deinit(self: *Context) void {
        self.response_buf.deinit(self.allocator);
    }
};

test "context reads path and method" {
    var ctx = Context.initTest(.GET, "/v1/models", std.testing.allocator);
    defer ctx.deinit();
    try std.testing.expectEqualStrings("/v1/models", ctx.path());
    try std.testing.expectEqual(std.http.Method.GET, ctx.method());
}

test "context stores and retrieves route params" {
    var ctx = Context.initTest(.GET, "/api/provider/gemini/v1/models", std.testing.allocator);
    defer ctx.deinit();
    ctx.setParam("provider", "gemini");
    try std.testing.expectEqualStrings("gemini", ctx.param("provider").?);
    try std.testing.expect(ctx.param("missing") == null);
}

test "context writes json response" {
    var ctx = Context.initTest(.GET, "/test", std.testing.allocator);
    defer ctx.deinit();
    const Payload = struct { message: []const u8 };
    try ctx.json(.ok, Payload{ .message = "hello" });
    const body = ctx.testResponseBody();
    try std.testing.expect(std.mem.indexOf(u8, body, "hello") != null);
}
