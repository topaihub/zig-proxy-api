const std = @import("std");
const context_mod = @import("context.zig");
const Handler = context_mod.Handler;

pub const ParamEntry = struct { key: []const u8, value: []const u8 };

pub const RouteMatch = struct {
    handler: Handler,
    params: [8]ParamEntry = undefined,
    param_count: u8 = 0,
};

const method_count = 9; // number of std.http.Method enum values

const NodeKind = enum { static, param, wildcard };

const Node = struct {
    kind: NodeKind,
    name: []const u8, // segment text for static, param/wildcard name without prefix
    handlers: [method_count]?Handler = .{null} ** method_count,
    children: std.ArrayListUnmanaged(*Node) = .empty,

    fn deinit(self: *Node, alloc: std.mem.Allocator) void {
        for (self.children.items) |child| child.deinit(alloc);
        self.children.deinit(alloc);
        alloc.destroy(self);
    }
};

fn methodIndex(m: std.http.Method) usize {
    return @intFromEnum(m);
}

pub const Group = struct {
    router: *Router,
    prefix: []const u8,

    pub fn get(self: Group, p: []const u8, h: Handler) void {
        self.router.addRoute(.GET, self.prefixed(p), h);
    }

    pub fn post(self: Group, p: []const u8, h: Handler) void {
        self.router.addRoute(.POST, self.prefixed(p), h);
    }

    fn prefixed(self: Group, p: []const u8) []const u8 {
        if (p.len == 0 or std.mem.eql(u8, p, "/")) return self.prefix;
        const buf = self.router.allocator.alloc(u8, self.prefix.len + p.len) catch @panic("OOM");
        @memcpy(buf[0..self.prefix.len], self.prefix);
        @memcpy(buf[self.prefix.len..], p);
        self.router.trackAlloc(buf);
        return buf;
    }
};

pub const Router = struct {
    allocator: std.mem.Allocator,
    root: *Node,
    alloc_bufs: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Router {
        const root = allocator.create(Node) catch @panic("OOM");
        root.* = .{ .kind = .static, .name = "" };
        return .{ .allocator = allocator, .root = root };
    }

    pub fn deinit(self: *Router) void {
        for (self.alloc_bufs.items) |buf| self.allocator.free(buf);
        self.alloc_bufs.deinit(self.allocator);
        self.root.deinit(self.allocator);
    }

    fn trackAlloc(self: *Router, buf: []const u8) void {
        self.alloc_bufs.append(self.allocator, buf) catch @panic("OOM");
    }

    pub fn get(self: *Router, p: []const u8, h: Handler) void {
        self.addRoute(.GET, p, h);
    }

    pub fn post(self: *Router, p: []const u8, h: Handler) void {
        self.addRoute(.POST, p, h);
    }

    pub fn group(self: *Router, prefix: []const u8) Group {
        return .{ .router = self, .prefix = prefix };
    }

    pub fn addRoute(self: *Router, m: std.http.Method, p: []const u8, h: Handler) void {
        var current = self.root;
        var iter = std.mem.splitScalar(u8, p, '/');
        while (iter.next()) |seg| {
            if (seg.len == 0) continue;
            current = self.getOrCreateChild(current, seg);
        }
        current.handlers[methodIndex(m)] = h;
    }

    pub fn resolve(self: *Router, m: std.http.Method, p: []const u8) ?RouteMatch {
        var result = RouteMatch{ .handler = undefined };
        result.param_count = 0;
        if (self.matchNode(self.root, p, m, &result)) return result;
        return null;
    }

    fn matchNode(self: *Router, node: *Node, remaining: []const u8, m: std.http.Method, result: *RouteMatch) bool {
        // Strip leading slashes and get segments
        const trimmed = std.mem.trimLeft(u8, remaining, "/");

        // Find next segment
        if (trimmed.len == 0) {
            // End of path — check handler
            if (node.handlers[methodIndex(m)]) |h| {
                result.handler = h;
                return true;
            }
            return false;
        }

        const sep = std.mem.indexOfScalar(u8, trimmed, '/');
        const seg = if (sep) |s| trimmed[0..s] else trimmed;
        const rest = if (sep) |s| trimmed[s + 1 ..] else "";

        // Priority: static > param > wildcard
        for (node.children.items) |child| {
            if (child.kind == .static and std.mem.eql(u8, child.name, seg)) {
                if (self.matchNode(child, rest, m, result)) return true;
            }
        }
        for (node.children.items) |child| {
            if (child.kind == .param) {
                const saved = result.param_count;
                if (result.param_count < 8) {
                    result.params[result.param_count] = .{ .key = child.name, .value = seg };
                    result.param_count += 1;
                }
                if (self.matchNode(child, rest, m, result)) return true;
                result.param_count = saved; // backtrack
            }
        }
        for (node.children.items) |child| {
            if (child.kind == .wildcard) {
                if (child.handlers[methodIndex(m)]) |h| {
                    if (result.param_count < 8) {
                        result.params[result.param_count] = .{ .key = child.name, .value = trimmed };
                        result.param_count += 1;
                    }
                    result.handler = h;
                    return true;
                }
            }
        }
        return false;
    }

    fn getOrCreateChild(self: *Router, parent: *Node, seg: []const u8) *Node {
        const kind: NodeKind = if (seg[0] == ':') .param else if (seg[0] == '*') .wildcard else .static;
        const name: []const u8 = if (kind != .static) seg[1..] else seg;

        for (parent.children.items) |child| {
            if (child.kind == kind and std.mem.eql(u8, child.name, name)) return child;
        }
        const child = self.allocator.create(Node) catch @panic("OOM");
        child.* = .{ .kind = kind, .name = name };
        parent.children.append(self.allocator, child) catch @panic("OOM");
        return child;
    }
};

// --- Tests ---

fn dummyHandler(_: *context_mod.Context) anyerror!void {}
fn dummyHandler2(_: *context_mod.Context) anyerror!void {}

test "static route matches" {
    var r = Router.init(std.testing.allocator);
    defer r.deinit();
    r.get("/api/health", dummyHandler);
    const m = r.resolve(.GET, "/api/health").?;
    try std.testing.expectEqual(@as(Handler, dummyHandler), m.handler);
    try std.testing.expectEqual(@as(u8, 0), m.param_count);
}

test "param route captures value" {
    var r = Router.init(std.testing.allocator);
    defer r.deinit();
    r.get("/users/:id", dummyHandler);
    const m = r.resolve(.GET, "/users/42").?;
    try std.testing.expectEqual(@as(Handler, dummyHandler), m.handler);
    try std.testing.expectEqual(@as(u8, 1), m.param_count);
    try std.testing.expectEqualStrings("id", m.params[0].key);
    try std.testing.expectEqualStrings("42", m.params[0].value);
}

test "wildcard route captures remaining path" {
    var r = Router.init(std.testing.allocator);
    defer r.deinit();
    r.get("/files/*path", dummyHandler);
    const m = r.resolve(.GET, "/files/a/b/c").?;
    try std.testing.expectEqual(@as(Handler, dummyHandler), m.handler);
    try std.testing.expectEqualStrings("path", m.params[0].key);
    try std.testing.expectEqualStrings("a/b/c", m.params[0].value);
}

test "unmatched returns null" {
    var r = Router.init(std.testing.allocator);
    defer r.deinit();
    r.get("/api/health", dummyHandler);
    try std.testing.expect(r.resolve(.GET, "/api/missing") == null);
    try std.testing.expect(r.resolve(.POST, "/api/health") == null);
}

test "group shares prefix and method-specific matching" {
    var r = Router.init(std.testing.allocator);
    defer r.deinit();
    const api = r.group("/api");
    api.get("/items", dummyHandler);
    api.post("/items", dummyHandler2);
    const gm = r.resolve(.GET, "/api/items").?;
    try std.testing.expectEqual(@as(Handler, dummyHandler), gm.handler);
    const pm = r.resolve(.POST, "/api/items").?;
    try std.testing.expectEqual(@as(Handler, dummyHandler2), pm.handler);
}
