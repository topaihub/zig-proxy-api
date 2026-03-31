const std = @import("std");

pub const Opcode = enum(u4) { continuation = 0x0, text = 0x1, binary = 0x2, close = 0x8, ping = 0x9, pong = 0xA };
pub const Message = struct { opcode: Opcode, payload: []const u8 };

pub fn encodeFrame(buf: *[256]u8, opcode: Opcode, payload: []const u8) usize {
    buf[0] = 0x80 | @as(u8, @intFromEnum(opcode));
    buf[1] = @intCast(payload.len);
    @memcpy(buf[2..][0..payload.len], payload);
    return 2 + payload.len;
}

pub fn encodeCloseFrame(buf: *[256]u8, code: u16, reason: []const u8) usize {
    buf[0] = 0x80 | @as(u8, @intFromEnum(Opcode.close));
    const plen: u8 = @intCast(2 + reason.len);
    buf[1] = plen;
    std.mem.writeInt(u16, buf[2..4], code, .big);
    @memcpy(buf[4..][0..reason.len], reason);
    return 2 + plen;
}

pub fn computeAcceptKey(key: []const u8) [28]u8 {
    const magic = "258EAFA5-E914-47DA-95CA-5AB53DC964B7";
    var h = std.crypto.hash.Sha1.init(.{});
    h.update(key);
    h.update(magic);
    const digest = h.finalResult();
    var out: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &digest);
    return out;
}

test "websocket frame encoding roundtrips" {
    var buf: [256]u8 = undefined;
    const payload = "hello websocket";
    const len = encodeFrame(&buf, .text, payload);
    const frame = buf[0..len];
    try std.testing.expectEqual(@as(u8, 0x81), frame[0]);
    try std.testing.expectEqual(@as(u8, payload.len), frame[1]);
    try std.testing.expectEqualStrings(payload, frame[2..][0..payload.len]);
}

test "websocket close frame" {
    var buf: [256]u8 = undefined;
    const len = encodeCloseFrame(&buf, 1000, "done");
    try std.testing.expect(len > 0);
    try std.testing.expectEqual(@as(u8, 0x88), buf[0]);
}
