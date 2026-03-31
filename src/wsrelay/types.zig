pub const WsMessage = struct {
    id: []const u8 = "",
    msg_type: MessageType = .http_req,
    payload: []const u8 = "",
};

pub const MessageType = enum {
    http_req,
    http_resp,
    stream_start,
    stream_chunk,
    stream_end,
    error_msg,

    pub fn name(self: MessageType) []const u8 {
        return switch (self) {
            .http_req => "http_req",
            .http_resp => "http_resp",
            .stream_start => "stream_start",
            .stream_chunk => "stream_chunk",
            .stream_end => "stream_end",
            .error_msg => "error",
        };
    }
};

test "message type names" {
    const std = @import("std");
    try std.testing.expectEqualStrings("http_req", MessageType.http_req.name());
    try std.testing.expectEqualStrings("error", MessageType.error_msg.name());
}
