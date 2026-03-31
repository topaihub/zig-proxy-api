const std = @import("std");

pub const Format = enum {
    openai,
    openai_response,
    claude,
    gemini,
    gemini_cli,
    codex,
    antigravity,

    pub fn name(self: Format) []const u8 {
        return switch (self) {
            .openai => "openai",
            .openai_response => "openai-response",
            .claude => "claude",
            .gemini => "gemini",
            .gemini_cli => "gemini-cli",
            .codex => "codex",
            .antigravity => "antigravity",
        };
    }
};

pub const RequestTransform = *const fn (model: []const u8, raw_json: []const u8, stream: bool) []const u8;
pub const ResponseStreamTransform = *const fn (model: []const u8, original_req: []const u8, translated_req: []const u8, raw_json: []const u8) []const []const u8;
pub const ResponseNonStreamTransform = *const fn (model: []const u8, original_req: []const u8, translated_req: []const u8, raw_json: []const u8) []const u8;

pub const ResponseTransform = struct {
    stream: ?ResponseStreamTransform = null,
    non_stream: ?ResponseNonStreamTransform = null,
};

pub const RequestEnvelope = struct {
    format: Format,
    model: []const u8 = "",
    stream: bool = false,
    body: []const u8 = "",
};

pub const ResponseEnvelope = struct {
    format: Format,
    model: []const u8 = "",
    stream: bool = false,
    body: []const u8 = "",
};

test "format names are correct" {
    try std.testing.expectEqualStrings("openai", Format.openai.name());
    try std.testing.expectEqualStrings("claude", Format.claude.name());
    try std.testing.expectEqualStrings("gemini-cli", Format.gemini_cli.name());
}
