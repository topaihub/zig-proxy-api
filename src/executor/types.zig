const std = @import("std");
const translator_types = @import("../translator/types.zig");

pub const Request = struct {
    model: []const u8 = "",
    payload: []const u8 = "",
    format: translator_types.Format = .openai,
};

pub const Options = struct {
    stream: bool = false,
    alt: []const u8 = "",
    original_request: []const u8 = "",
    source_format: translator_types.Format = .openai,
};

pub const Response = struct {
    status_code: u16 = 200,
    payload: []const u8 = "",
    headers: []const Header = &.{},
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Executor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, req: Request, opts: Options) anyerror!Response,
        provider_name: *const fn (ptr: *anyopaque) []const u8,
    };

    pub fn execute(self: Executor, allocator: std.mem.Allocator, req: Request, opts: Options) !Response {
        return self.vtable.execute(self.ptr, allocator, req, opts);
    }

    pub fn providerName(self: Executor) []const u8 {
        return self.vtable.provider_name(self.ptr);
    }
};

test "request has default format" {
    const req = Request{};
    try std.testing.expectEqualStrings("openai", req.format.name());
}
