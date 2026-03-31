# Sub-Project 1: Project Scaffold + HTTP Server — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `zig-proxy-api` project with zig-framework dependency and a working HTTP server module with router, middleware, SSE, and WebSocket support.

**Architecture:** Standalone Zig project depending on zig-framework (vnext branch) as a library. HTTP server built on `std.http.Server`, with radix tree router, chainable middleware, SSE streaming, and WebSocket upgrade. Integrates with framework's AppContext for logging, tracing, and observability.

**Tech Stack:** Zig 0.15.2+, zig-framework (codex/framework-tooling-runtime-vnext), std.http.Server, std.json

---

## File Structure

| File | Responsibility |
|------|---------------|
| `build.zig` | Build configuration, framework dependency |
| `build.zig.zon` | Package manifest |
| `src/main.zig` | Entry point, bootstrap server |
| `src/server/root.zig` | Module exports |
| `src/server/context.zig` | Per-request context: params, body, headers, response writing |
| `src/server/router.zig` | Radix tree router with groups, params, wildcards |
| `src/server/middleware.zig` | Middleware chain, built-in middleware (CORS, request_id, recovery) |
| `src/server/sse.zig` | SSE streaming writer |
| `src/server/websocket.zig` | WebSocket upgrade and frame I/O |
| `src/server/http_server.zig` | Server lifecycle: listen, accept, shutdown, AppContext integration |

---

### Task 1: Project Scaffold

**Files:**
- Create: `build.zig.zon`
- Create: `build.zig`
- Create: `src/main.zig`
- Create: `.gitignore`

- [ ] **Step 1: Create build.zig.zon**

```zig
.{
    .name = .zig_proxy_api,
    .version = "0.1.0",
    .minimum_zig_version = "0.15.2",
    .dependencies = .{
        .framework = .{
            .url = "https://github.com/topaihub/zig-framework/archive/codex/framework-tooling-runtime-vnext.tar.gz",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

- [ ] **Step 2: Create build.zig**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const framework_dep = b.dependency("framework", .{
        .target = target,
        .optimize = optimize,
    });
    const framework_mod = framework_dep.module("framework");

    const exe = b.addExecutable(.{
        .name = "zig-proxy-api",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("framework", framework_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run zig-proxy-api");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("framework", framework_mod);
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
```

- [ ] **Step 3: Create minimal src/main.zig**

```zig
const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("zig-proxy-api bootstrap ready\n");
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}
```

- [ ] **Step 4: Create .gitignore**

```
.zig-cache/
zig-out/
```

- [ ] **Step 5: Verify build compiles**

Run: `cd /tmp/zig-proxy-api && zig build 2>&1`
Expected: Build succeeds (or dependency fetch needed — if so, run `zig fetch` first)

Note: The framework dependency URL may need a hash. If `zig build` reports a missing hash, copy the hash it provides into `build.zig.zon` under `.framework`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: project scaffold with zig-framework dependency"
```

---

### Task 2: Context — Request/Response Abstraction

**Files:**
- Create: `src/server/context.zig`

- [ ] **Step 1: Write the failing test**

```zig
// At bottom of src/server/context.zig

test "context reads path and method" {
    // We test Context with a mock — no real HTTP needed
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
    try std.testing.expect(std.mem.indexOf(u8, body, "\"message\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"hello\"") != null);
}
```

- [ ] **Step 2: Implement Context**

```zig
const std = @import("std");

pub const Handler = *const fn (*Context) anyerror!void;

pub const Context = struct {
    allocator: std.mem.Allocator,
    request_method: std.http.Method,
    request_path: []const u8,
    request_body: ?[]const u8 = null,
    request_headers: ?*const std.http.Header.FieldTable = null,
    params: [8]ParamEntry = undefined,
    param_count: u8 = 0,
    query_string: ?[]const u8 = null,

    // Response state
    response_buf: std.ArrayListUnmanaged(u8) = .empty,
    response_status: std.http.Status = .ok,
    response_headers: [16]HeaderEntry = undefined,
    response_header_count: u8 = 0,
    response_started: bool = false,

    // Real server connection (null in tests)
    server_response: ?*std.http.Server.Response = null,

    const ParamEntry = struct { key: []const u8, value: []const u8 };
    const HeaderEntry = struct { name: []const u8, value: []const u8 };

    pub fn path(self: *const Context) []const u8 {
        return self.request_path;
    }

    pub fn method(self: *const Context) std.http.Method {
        return self.request_method;
    }

    pub fn param(self: *const Context, key: []const u8) ?[]const u8 {
        for (self.params[0..self.param_count]) |entry| {
            if (std.mem.eql(u8, entry.key, key)) return entry.value;
        }
        return null;
    }

    pub fn setParam(self: *Context, key: []const u8, value: []const u8) void {
        if (self.param_count < self.params.len) {
            self.params[self.param_count] = .{ .key = key, .value = value };
            self.param_count += 1;
        }
    }

    pub fn query(self: *const Context, key: []const u8) ?[]const u8 {
        const qs = self.query_string orelse return null;
        var iter = std.mem.splitScalar(u8, qs, '&');
        while (iter.next()) |pair| {
            if (std.mem.indexOfScalar(u8, pair, '=')) |eq| {
                if (std.mem.eql(u8, pair[0..eq], key)) return pair[eq + 1 ..];
            }
        }
        return null;
    }

    pub fn header(self: *const Context, name: []const u8) ?[]const u8 {
        _ = self;
        _ = name;
        // TODO: wire to real headers in http_server integration
        return null;
    }

    pub fn readBody(self: *const Context) ?[]const u8 {
        return self.request_body;
    }

    pub fn setStatus(self: *Context, status: std.http.Status) void {
        self.response_status = status;
    }

    pub fn setHeader(self: *Context, name: []const u8, value: []const u8) void {
        if (self.response_header_count < self.response_headers.len) {
            self.response_headers[self.response_header_count] = .{ .name = name, .value = value };
            self.response_header_count += 1;
        }
    }

    pub fn json(self: *Context, status: std.http.Status, value: anytype) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "application/json");
        std.json.stringify(value, .{}, self.response_buf.writer(self.allocator)) catch |err| return err;
    }

    pub fn text(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "text/plain");
        try self.response_buf.appendSlice(self.allocator, body);
    }

    pub fn html(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        self.setHeader("Content-Type", "text/html; charset=utf-8");
        try self.response_buf.appendSlice(self.allocator, body);
    }

    pub fn raw(self: *Context, status: std.http.Status, body: []const u8) !void {
        self.response_status = status;
        try self.response_buf.appendSlice(self.allocator, body);
    }

    // --- Test helpers ---

    pub fn initTest(m: std.http.Method, p: []const u8, allocator: std.mem.Allocator) Context {
        return .{ .allocator = allocator, .request_method = m, .request_path = p };
    }

    pub fn testResponseBody(self: *const Context) []const u8 {
        return self.response_buf.items;
    }

    pub fn deinit(self: *Context) void {
        self.response_buf.deinit(self.allocator);
    }
};
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: All 3 tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/server/context.zig
git commit -m "feat(server): add request/response Context"
```

---

### Task 3: Router — Radix Tree with Params and Wildcards

**Files:**
- Create: `src/server/router.zig`

- [ ] **Step 1: Write the failing tests**

```zig
// At bottom of src/server/router.zig

test "router matches static route" {
    var router = Router.init(std.testing.allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(ctx: *Context) anyerror!void {
            try ctx.text(.ok, "root");
        }
    }.handle;

    try router.addRoute(.GET, "/", handler);
    var match = router.resolve(.GET, "/");
    try std.testing.expect(match != null);
}

test "router matches param route" {
    var router = Router.init(std.testing.allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(_: *Context) anyerror!void {}
    }.handle;

    try router.addRoute(.GET, "/api/provider/:provider/models", handler);
    var match = router.resolve(.GET, "/api/provider/gemini/models");
    try std.testing.expect(match != null);
    try std.testing.expectEqualStrings("gemini", match.?.params[0].value);
}

test "router matches wildcard route" {
    var router = Router.init(std.testing.allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(_: *Context) anyerror!void {}
    }.handle;

    try router.addRoute(.POST, "/v1beta/models/*action", handler);
    var match = router.resolve(.POST, "/v1beta/models/gemini-2.5-pro:generateContent");
    try std.testing.expect(match != null);
    try std.testing.expectEqualStrings("gemini-2.5-pro:generateContent", match.?.params[0].value);
}

test "router returns null for unmatched" {
    var router = Router.init(std.testing.allocator);
    defer router.deinit();

    try std.testing.expect(router.resolve(.GET, "/nothing") == null);
}

test "router group shares prefix" {
    var router = Router.init(std.testing.allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(_: *Context) anyerror!void {}
    }.handle;

    var v1 = router.group("/v1");
    try v1.get("/models", handler);
    try v1.post("/chat/completions", handler);

    try std.testing.expect(router.resolve(.GET, "/v1/models") != null);
    try std.testing.expect(router.resolve(.POST, "/v1/chat/completions") != null);
    try std.testing.expect(router.resolve(.GET, "/v1/chat/completions") == null);
}
```

- [ ] **Step 2: Implement Router**

The router uses a simple segment-based tree (not a compressed radix tree — simpler, sufficient for ~30 routes).

```zig
const std = @import("std");
const context_mod = @import("context.zig");
const Context = context_mod.Context;
const Handler = context_mod.Handler;

pub const RouteMatch = struct {
    handler: Handler,
    params: [8]Context.ParamEntry = undefined,
    param_count: u8 = 0,
};

const NodeKind = enum { static, param, wildcard };

const Node = struct {
    segment: []const u8,
    kind: NodeKind,
    handlers: [9]?Handler = .{null} ** 9, // indexed by std.http.Method
    children: std.ArrayListUnmanaged(*Node) = .empty,

    fn methodIndex(m: std.http.Method) usize {
        return switch (m) {
            .GET => 0,
            .POST => 1,
            .PUT => 2,
            .DELETE => 3,
            .PATCH => 4,
            .HEAD => 5,
            .OPTIONS => 6,
            .CONNECT => 7,
            .TRACE => 8,
            else => 0,
        };
    }
};

pub const Group = struct {
    router: *Router,
    prefix: []const u8,

    pub fn get(self: *Group, path: []const u8, handler: Handler) !void {
        try self.router.addRoute(.GET, self.fullPath(path), handler);
    }

    pub fn post(self: *Group, path: []const u8, handler: Handler) !void {
        try self.router.addRoute(.POST, self.fullPath(path), handler);
    }

    fn fullPath(self: *const Group, path: []const u8) []const u8 {
        // prefix already stored with path appended during group creation
        _ = self;
        return path;
    }
};

pub const Router = struct {
    allocator: std.mem.Allocator,
    root: *Node,
    groups: std.ArrayListUnmanaged(GroupEntry) = .empty,
    path_buf: [512]u8 = undefined,

    const GroupEntry = struct { prefix: []const u8, group: Group };

    pub fn init(allocator: std.mem.Allocator) Router {
        const root = allocator.create(Node) catch @panic("OOM");
        root.* = .{ .segment = "", .kind = .static };
        return .{ .allocator = allocator, .root = root };
    }

    pub fn deinit(self: *Router) void {
        self.freeNode(self.root);
        self.groups.deinit(self.allocator);
    }

    fn freeNode(self: *Router, node: *Node) void {
        for (node.children.items) |child| self.freeNode(child);
        node.children.deinit(self.allocator);
        self.allocator.destroy(node);
    }

    pub fn group(self: *Router, prefix: []const u8) Group {
        var g = Group{ .router = self, .prefix = prefix };
        // Override get/post to prepend prefix
        g = .{
            .router = self,
            .prefix = prefix,
        };
        return g;
    }

    pub fn addRoute(self: *Router, m: std.http.Method, path: []const u8, handler: Handler) !void {
        var segments = splitPath(path);
        var current = self.root;
        while (segments.next()) |seg| {
            current = try self.findOrCreateChild(current, seg);
        }
        current.handlers[Node.methodIndex(m)] = handler;
    }

    pub fn resolve(self: *Router, m: std.http.Method, path: []const u8) ?RouteMatch {
        var match = RouteMatch{};
        if (self.matchNode(self.root, path, splitPath(path), &match)) {
            if (match.handler != undefined) return match;
            const h = self.root.handlers[Node.methodIndex(m)];
            _ = h;
        }
        var segments = splitPath(path);
        var result = RouteMatch{};
        if (self.resolveInner(self.root, &segments, m, &result)) {
            return result;
        }
        return null;
    }

    fn resolveInner(self: *Router, node: *Node, segments: *SegmentIter, m: std.http.Method, result: *RouteMatch) bool {
        const seg = segments.next() orelse {
            const h = node.handlers[Node.methodIndex(m)] orelse return false;
            result.handler = h;
            return true;
        };

        // Try static children first
        for (node.children.items) |child| {
            switch (child.kind) {
                .static => {
                    if (std.mem.eql(u8, child.segment, seg)) {
                        if (self.resolveInner(child, segments, m, result)) return true;
                    }
                },
                else => {},
            }
        }
        // Then param children
        for (node.children.items) |child| {
            if (child.kind == .param) {
                if (result.param_count < result.params.len) {
                    result.params[result.param_count] = .{ .key = child.segment, .value = seg };
                    result.param_count += 1;
                }
                if (self.resolveInner(child, segments, m, result)) return true;
                result.param_count -= 1;
            }
        }
        // Then wildcard children
        for (node.children.items) |child| {
            if (child.kind == .wildcard) {
                // Wildcard captures this segment + all remaining
                var rest_buf: [512]u8 = undefined;
                var rest_len: usize = 0;
                @memcpy(rest_buf[0..seg.len], seg);
                rest_len = seg.len;
                while (segments.next()) |remaining| {
                    rest_buf[rest_len] = '/';
                    rest_len += 1;
                    @memcpy(rest_buf[rest_len..][0..remaining.len], remaining);
                    rest_len += remaining.len;
                }
                const h = child.handlers[Node.methodIndex(m)] orelse return false;
                if (result.param_count < result.params.len) {
                    result.params[result.param_count] = .{ .key = child.segment, .value = rest_buf[0..rest_len] };
                    result.param_count += 1;
                }
                result.handler = h;
                return true;
            }
        }
        return false;
    }

    fn findOrCreateChild(self: *Router, parent: *Node, segment: []const u8) !*Node {
        const kind: NodeKind = if (segment.len > 0 and segment[0] == ':')
            .param
        else if (segment.len > 0 and segment[0] == '*')
            .wildcard
        else
            .static;

        const name = if (kind == .param or kind == .wildcard) segment[1..] else segment;

        for (parent.children.items) |child| {
            if (child.kind == kind and std.mem.eql(u8, child.segment, name)) return child;
        }

        const child = try self.allocator.create(Node);
        child.* = .{ .segment = name, .kind = kind };
        try parent.children.append(self.allocator, child);
        return child;
    }

    // Group helpers that prepend prefix
    pub fn get(self: *Router, path: []const u8, handler: Handler) !void {
        try self.addRoute(.GET, path, handler);
    }

    pub fn post(self: *Router, path: []const u8, handler: Handler) !void {
        try self.addRoute(.POST, path, handler);
    }

    const SegmentIter = struct {
        path: []const u8,
        pos: usize = 0,

        fn next(self: *SegmentIter) ?[]const u8 {
            while (self.pos < self.path.len and self.path[self.pos] == '/') self.pos += 1;
            if (self.pos >= self.path.len) return null;
            const start = self.pos;
            while (self.pos < self.path.len and self.path[self.pos] != '/') self.pos += 1;
            return self.path[start..self.pos];
        }
    };

    fn splitPath(path: []const u8) SegmentIter {
        return .{ .path = path };
    }

    fn matchNode(self: *Router, node: *Node, path: []const u8, segments: SegmentIter, match: *RouteMatch) bool {
        _ = self;
        _ = node;
        _ = path;
        _ = segments;
        _ = match;
        return false;
    }
};
```

Note: The `Group.get`/`Group.post` methods need to concatenate prefix + path. Updated implementation:

```zig
// Replace Group.get and Group.post:
pub fn get(self: *Group, sub_path: []const u8, handler: Handler) !void {
    var buf: [512]u8 = undefined;
    const full = self.concatPath(&buf, sub_path);
    try self.router.addRoute(.GET, full, handler);
}

pub fn post(self: *Group, sub_path: []const u8, handler: Handler) !void {
    var buf: [512]u8 = undefined;
    const full = self.concatPath(&buf, sub_path);
    try self.router.addRoute(.POST, full, handler);
}

fn concatPath(self: *const Group, buf: *[512]u8, sub_path: []const u8) []const u8 {
    @memcpy(buf[0..self.prefix.len], self.prefix);
    @memcpy(buf[self.prefix.len..][0..sub_path.len], sub_path);
    return buf[0 .. self.prefix.len + sub_path.len];
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: All 5 router tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/server/router.zig
git commit -m "feat(server): add radix tree Router with params and wildcards"
```

---

### Task 4: Middleware Chain

**Files:**
- Create: `src/server/middleware.zig`

- [ ] **Step 1: Write the failing tests**

```zig
// At bottom of src/server/middleware.zig

test "middleware chain executes in order" {
    const M1 = struct {
        fn call(ctx: *Context, next: Handler) anyerror!void {
            try ctx.response_buf.appendSlice(ctx.allocator, "m1>");
            try next(ctx);
        }
    };
    const M2 = struct {
        fn call(ctx: *Context, next: Handler) anyerror!void {
            try ctx.response_buf.appendSlice(ctx.allocator, "m2>");
            try next(ctx);
        }
    };
    const Final = struct {
        fn handle(ctx: *Context) anyerror!void {
            try ctx.response_buf.appendSlice(ctx.allocator, "done");
        }
    };

    const chain = buildChain(&.{ M1.call, M2.call }, Final.handle);
    var ctx = Context.initTest(.GET, "/test", std.testing.allocator);
    defer ctx.deinit();
    try chain(&ctx);
    try std.testing.expectEqualStrings("m1>m2>done", ctx.testResponseBody());
}

test "middleware can short-circuit" {
    const Auth = struct {
        fn call(ctx: *Context, _: Handler) anyerror!void {
            try ctx.text(.unauthorized, "denied");
            // Does NOT call next
        }
    };
    const Final = struct {
        fn handle(ctx: *Context) anyerror!void {
            try ctx.text(.ok, "should not reach");
        }
    };

    const chain = buildChain(&.{Auth.call}, Final.handle);
    var ctx = Context.initTest(.GET, "/secret", std.testing.allocator);
    defer ctx.deinit();
    try chain(&ctx);
    try std.testing.expectEqualStrings("denied", ctx.testResponseBody());
    try std.testing.expectEqual(std.http.Status.unauthorized, ctx.response_status);
}
```

- [ ] **Step 2: Implement middleware chain builder**

```zig
const std = @import("std");
const context_mod = @import("context.zig");
const Context = context_mod.Context;
const Handler = context_mod.Handler;

pub const Middleware = *const fn (*Context, Handler) anyerror!void;

/// Builds a single Handler that chains middlewares around a final handler.
/// Middlewares execute left-to-right; each calls `next` to proceed.
pub fn buildChain(middlewares: []const Middleware, final: Handler) Handler {
    if (middlewares.len == 0) return final;

    // We build from the inside out: wrap final with last middleware, then next-to-last, etc.
    // Since we need a function pointer, we use a comptime trick with closures isn't possible.
    // Instead, we store the chain in a thread-local for dispatch.
    // For simplicity and zero-alloc, we use a bounded static chain.
    const Static = struct {
        var chain: [32]Middleware = undefined;
        var chain_len: usize = 0;
        var final_handler: Handler = undefined;

        fn dispatch(ctx: *Context) anyerror!void {
            return dispatchAt(ctx, 0);
        }

        fn dispatchAt(ctx: *Context, index: usize) anyerror!void {
            if (index >= chain_len) return final_handler(ctx);
            const mw = chain[index];
            const next_handler = makeNext(index + 1);
            return mw(ctx, next_handler);
        }

        fn makeNext(index: usize) Handler {
            // We need a function pointer per index. Use a lookup table.
            const handlers = comptime blk: {
                var h: [32]Handler = undefined;
                for (0..32) |i| {
                    h[i] = makeIndexedHandler(i);
                }
                break :blk h;
            };
            return handlers[index];
        }

        fn makeIndexedHandler(comptime i: usize) Handler {
            return struct {
                fn handle(ctx: *Context) anyerror!void {
                    return dispatchAt(ctx, i);
                }
            }.handle;
        }
    };

    @memcpy(Static.chain[0..middlewares.len], middlewares);
    Static.chain_len = middlewares.len;
    Static.final_handler = final;
    return Static.dispatch;
}

// --- Built-in middleware ---

/// Generates a unique request ID and stores it in context.
pub fn requestId(ctx: *Context, next: Handler) anyerror!void {
    // Simple incrementing ID for now
    const Static = struct {
        var counter: u64 = 0;
    };
    _ = @atomicRmw(u64, &Static.counter, .Add, 1, .monotonic);
    ctx.setHeader("X-Request-Id", "req");
    try next(ctx);
}

/// CORS middleware: handles preflight and sets response headers.
pub fn cors(ctx: *Context, next: Handler) anyerror!void {
    ctx.setHeader("Access-Control-Allow-Origin", "*");
    ctx.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH");
    ctx.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Api-Key, anthropic-version");
    if (ctx.method() == .OPTIONS) {
        ctx.setStatus(.no_content);
        return;
    }
    try next(ctx);
}

/// Recovery middleware: catches handler errors and returns 500.
pub fn recovery(ctx: *Context, next: Handler) anyerror!void {
    next(ctx) catch |err| {
        ctx.json(.internal_server_error, .{
            .@"error" = .{
                .message = "Internal server error",
                .type = "server_error",
                .code = @errorName(err),
            },
        }) catch {};
    };
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: Both middleware tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/server/middleware.zig
git commit -m "feat(server): add middleware chain with CORS, request_id, recovery"
```

---

### Task 5: SSE Streaming Writer

**Files:**
- Create: `src/server/sse.zig`

- [ ] **Step 1: Write the failing test**

```zig
// At bottom of src/server/sse.zig

test "sse writer formats events correctly" {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(std.testing.allocator);

    var writer = SseWriter.initTest(&buf, std.testing.allocator);
    try writer.writeEvent("data: {\"chunk\":1}\n\n");
    try writer.writeKeepAlive();

    const output = buf.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "data: {\"chunk\":1}\n\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, ": keep-alive\n\n") != null);
}
```

- [ ] **Step 2: Implement SseWriter**

```zig
const std = @import("std");

pub const SseWriter = struct {
    buf: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    server_response: ?*std.http.Server.Response = null,

    pub fn initTest(buf: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) SseWriter {
        return .{ .buf = buf, .allocator = allocator };
    }

    pub fn writeEvent(self: *SseWriter, data: []const u8) !void {
        try self.buf.appendSlice(self.allocator, data);
        if (self.server_response) |resp| resp.flush() catch {};
    }

    pub fn writeKeepAlive(self: *SseWriter) !void {
        try self.buf.appendSlice(self.allocator, ": keep-alive\n\n");
        if (self.server_response) |resp| resp.flush() catch {};
    }

    pub fn writeData(self: *SseWriter, data: []const u8) !void {
        try self.buf.appendSlice(self.allocator, "data: ");
        try self.buf.appendSlice(self.allocator, data);
        try self.buf.appendSlice(self.allocator, "\n\n");
        if (self.server_response) |resp| resp.flush() catch {};
    }

    pub fn writeDone(self: *SseWriter) !void {
        try self.buf.appendSlice(self.allocator, "data: [DONE]\n\n");
        if (self.server_response) |resp| resp.flush() catch {};
    }

    pub fn flush(self: *SseWriter) !void {
        if (self.server_response) |resp| resp.flush() catch {};
    }
};
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: SSE test PASS

- [ ] **Step 4: Commit**

```bash
git add src/server/sse.zig
git commit -m "feat(server): add SSE streaming writer"
```

---

### Task 6: WebSocket

**Files:**
- Create: `src/server/websocket.zig`

- [ ] **Step 1: Write the failing test**

```zig
// At bottom of src/server/websocket.zig

test "websocket frame encoding roundtrips" {
    var buf: [256]u8 = undefined;
    const payload = "hello websocket";
    const len = encodeFrame(&buf, .text, payload);
    const frame = buf[0..len];

    // First byte: FIN + text opcode
    try std.testing.expectEqual(@as(u8, 0x81), frame[0]);
    // Second byte: length (no mask)
    try std.testing.expectEqual(@as(u8, payload.len), frame[1]);
    // Payload
    try std.testing.expectEqualStrings(payload, frame[2..][0..payload.len]);
}

test "websocket close frame" {
    var buf: [256]u8 = undefined;
    const len = encodeCloseFrame(&buf, 1000, "done");
    try std.testing.expect(len > 0);
    // First byte: FIN + close opcode (0x88)
    try std.testing.expectEqual(@as(u8, 0x88), buf[0]);
}
```

- [ ] **Step 2: Implement WebSocket frame encoding**

```zig
const std = @import("std");

pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

pub const Message = struct {
    opcode: Opcode,
    payload: []const u8,
};

pub fn encodeFrame(buf: *[256]u8, opcode: Opcode, payload: []const u8) usize {
    buf[0] = 0x80 | @intFromEnum(opcode); // FIN + opcode
    var offset: usize = 1;
    if (payload.len < 126) {
        buf[offset] = @intCast(payload.len);
        offset += 1;
    } else if (payload.len <= 65535) {
        buf[offset] = 126;
        offset += 1;
        buf[offset] = @intCast((payload.len >> 8) & 0xFF);
        buf[offset + 1] = @intCast(payload.len & 0xFF);
        offset += 2;
    }
    @memcpy(buf[offset..][0..payload.len], payload);
    return offset + payload.len;
}

pub fn encodeCloseFrame(buf: *[256]u8, code: u16, reason: []const u8) usize {
    buf[0] = 0x80 | @intFromEnum(Opcode.close);
    const payload_len = 2 + reason.len;
    buf[1] = @intCast(payload_len);
    buf[2] = @intCast((code >> 8) & 0xFF);
    buf[3] = @intCast(code & 0xFF);
    @memcpy(buf[4..][0..reason.len], reason);
    return 4 + reason.len;
}

pub fn computeAcceptKey(key: []const u8) [28]u8 {
    const magic = "258EAFA5-E914-47DA-95CA-5AB5ADF35F20";
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(key);
    hasher.update(magic);
    const hash = hasher.finalResult();
    var result: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&result, &hash);
    return result;
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: Both WebSocket tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/server/websocket.zig
git commit -m "feat(server): add WebSocket frame encoding"
```

---

### Task 7: Module Root

**Files:**
- Create: `src/server/root.zig`

- [ ] **Step 1: Create module root that exports all types**

```zig
pub const context = @import("context.zig");
pub const router = @import("router.zig");
pub const middleware = @import("middleware.zig");
pub const sse = @import("sse.zig");
pub const websocket = @import("websocket.zig");

pub const Context = context.Context;
pub const Handler = context.Handler;
pub const Router = router.Router;
pub const RouteMatch = router.RouteMatch;
pub const Group = router.Group;
pub const Middleware = middleware.Middleware;
pub const buildChain = middleware.buildChain;
pub const SseWriter = sse.SseWriter;
pub const WebSocketOpcode = websocket.Opcode;

test {
    @import("std").testing.refAllDecls(@This());
}
```

- [ ] **Step 2: Update src/main.zig to import server module**

```zig
const std = @import("std");
const framework = @import("framework");
pub const server = @import("server/root.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("zig-proxy-api bootstrap ready\n");
}

test "framework import works" {
    try std.testing.expect(framework.PACKAGE_NAME.len > 0);
}

test {
    std.testing.refAllDecls(@This());
}
```

- [ ] **Step 3: Run all tests**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: All tests PASS (context, router, middleware, sse, websocket)

- [ ] **Step 4: Commit**

```bash
git add src/server/root.zig src/main.zig
git commit -m "feat(server): add module root, wire all components"
```

---

### Task 8: HTTP Server with AppContext Integration

**Files:**
- Create: `src/server/http_server.zig`
- Modify: `src/server/root.zig`

- [ ] **Step 1: Write the failing test**

```zig
// At bottom of src/server/http_server.zig

test "http server initializes with config" {
    const framework = @import("framework");
    var app_ctx = try framework.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_ctx.deinit();

    var srv = HttpServer.init(std.testing.allocator, .{
        .host = "127.0.0.1",
        .port = 0, // ephemeral
        .app_context = &app_ctx,
    });
    defer srv.deinit();

    try std.testing.expectEqualStrings("127.0.0.1", srv.config.host);
    try std.testing.expect(srv.router != null);
}
```

- [ ] **Step 2: Implement HttpServer**

```zig
const std = @import("std");
const framework = @import("framework");
const router_mod = @import("router.zig");
const context_mod = @import("context.zig");
const middleware_mod = @import("middleware.zig");

pub const ServerConfig = struct {
    host: []const u8 = "0.0.0.0",
    port: u16 = 8317,
    app_context: ?*framework.AppContext = null,
};

pub const HttpServer = struct {
    allocator: std.mem.Allocator,
    config: ServerConfig,
    router: router_mod.Router,
    app_context: ?*framework.AppContext,
    global_middlewares: [16]middleware_mod.Middleware = undefined,
    global_mw_count: u8 = 0,
    shutdown_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) HttpServer {
        return .{
            .allocator = allocator,
            .config = config,
            .router = router_mod.Router.init(allocator),
            .app_context = config.app_context,
        };
    }

    pub fn deinit(self: *HttpServer) void {
        self.router.deinit();
    }

    pub fn use(self: *HttpServer, mw: middleware_mod.Middleware) void {
        if (self.global_mw_count < self.global_middlewares.len) {
            self.global_middlewares[self.global_mw_count] = mw;
            self.global_mw_count += 1;
        }
    }

    pub fn shutdown(self: *HttpServer) void {
        self.shutdown_requested.store(true, .release);
    }

    pub fn listenAndServe(self: *HttpServer) !void {
        const address = try std.net.Address.parseIp(self.config.host, self.config.port);
        var tcp_server = try address.listen(.{});
        defer tcp_server.deinit();

        if (self.app_context) |ctx| {
            ctx.logger.info("server listening", &.{
                framework.LogField.string("host", self.config.host),
                framework.LogField.int("port", @intCast(self.config.port)),
            });
        }

        while (!self.shutdown_requested.load(.acquire)) {
            const conn = tcp_server.accept() catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };
            self.handleConnection(conn) catch {};
        }
    }

    fn handleConnection(self: *HttpServer, conn: std.net.Server.Connection) !void {
        defer conn.stream.close();
        var http_server = std.http.Server.init(conn, .{});

        var request = http_server.receiveHead() catch return;
        const target = request.head.target;

        // Split target into path and query
        var req_path = target;
        var query_string: ?[]const u8 = null;
        if (std.mem.indexOfScalar(u8, target, '?')) |qi| {
            req_path = target[0..qi];
            query_string = target[qi + 1 ..];
        }

        var ctx = context_mod.Context{
            .allocator = self.allocator,
            .request_method = request.head.method,
            .request_path = req_path,
            .query_string = query_string,
        };
        defer ctx.deinit();

        // Resolve route
        if (self.router.resolve(request.head.method, req_path)) |match| {
            // Copy params
            for (match.params[0..match.param_count]) |p| ctx.setParam(p.key, p.value);

            // Build middleware chain
            const handler = middleware_mod.buildChain(
                self.global_middlewares[0..self.global_mw_count],
                match.handler,
            );
            handler(&ctx) catch {};
        } else {
            ctx.json(.not_found, .{
                .@"error" = .{ .message = "Not found", .type = "not_found" },
            }) catch {};
        }

        // Write response
        request.respond(ctx.response_buf.items, .{
            .status = ctx.response_status,
        }) catch {};
    }
};
```

- [ ] **Step 3: Add HttpServer to root.zig**

Add to `src/server/root.zig`:

```zig
pub const http_server = @import("http_server.zig");
pub const HttpServer = http_server.HttpServer;
pub const ServerConfig = http_server.ServerConfig;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /tmp/zig-proxy-api && zig build test 2>&1`
Expected: All tests PASS including HttpServer init test

- [ ] **Step 5: Commit**

```bash
git add src/server/http_server.zig src/server/root.zig
git commit -m "feat(server): add HttpServer with AppContext integration"
```

---

### Task 9: Integration Smoke Test

**Files:**
- Modify: `src/main.zig`

- [ ] **Step 1: Update main.zig with a working server example**

```zig
const std = @import("std");
const framework = @import("framework");
pub const server = @import("server/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app_ctx = try framework.AppContext.init(allocator, .{});
    defer app_ctx.deinit();

    var srv = server.HttpServer.init(allocator, .{
        .host = "127.0.0.1",
        .port = 8317,
        .app_context = &app_ctx,
    });
    defer srv.deinit();

    srv.use(server.middleware.cors);
    srv.use(server.middleware.recovery);

    try srv.router.get("/", rootHandler);

    var v1 = srv.router.group("/v1");
    try v1.get("/models", modelsHandler);

    app_ctx.logger.info("zig-proxy-api starting", &.{});
    try srv.listenAndServe();
}

fn rootHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{
        .message = "CLI Proxy API Server (Zig)",
        .endpoints = &[_][]const u8{
            "POST /v1/chat/completions",
            "GET /v1/models",
        },
    });
}

fn modelsHandler(ctx: *server.Context) anyerror!void {
    try ctx.json(.ok, .{
        .object = "list",
        .data = &[_]struct { id: []const u8, object: []const u8 }{
            .{ .id = "gemini-2.5-pro", .object = "model" },
            .{ .id = "claude-sonnet-4", .object = "model" },
        },
    });
}

test {
    std.testing.refAllDecls(@This());
}
```

- [ ] **Step 2: Verify build succeeds**

Run: `cd /tmp/zig-proxy-api && zig build 2>&1`
Expected: Build succeeds, binary at `zig-out/bin/zig-proxy-api`

- [ ] **Step 3: Commit**

```bash
git add src/main.zig
git commit -m "feat: integration smoke test with working server example"
```
