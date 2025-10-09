const std = @import("std");
const mibu = @import("mibu");

const utils = @import("char_utils.zig");
const Self = @This();

pub const Color = union(enum) {
    default,
    xterm: mibu.color.Color,
    rgb: struct { r: u8, g: u8, b: u8 },
};

pub const Attr = packed struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    reverse: bool = false,
    blink: bool = false,
    strikethrough: bool = false,
};

pub const Style = struct {
    bg: Color = .default,
    fg: Color = .default,
    attr: Attr = .{},

    pub fn equals(a: Style, b: Style) bool {
        return std.meta.eql(a, b);
    }
};

/// `is_wide` is set automatically when `setCh` is called
is_wide: bool = false,

/// The consumer (runestone) should write this value
is_continuation: bool = false,

/// Stores up to 4 bytes for a UTF-8 character.
/// Shouldn't be modified without using `setCh`
utf8_buf: [4]u8 = [_]u8{ ' ', 0, 0, 0 },
utf8_len: u3 = 1,

style: Style = .{},
z_index: usize = 0,

/// Sets the cell's character from a UTF-8 codepoint slice.
pub fn setCh(self: *Self, codepoint: []const u8) void {
    const len = std.unicode.utf8ByteSequenceLength(codepoint[0]) catch 1;
    const copy_len = @min(codepoint.len, len, 4);
    @memcpy(self.utf8_buf[0..copy_len], codepoint[0..copy_len]);
    self.utf8_len = @intCast(copy_len);

    self.is_wide = utils.isWideCharacter(codepoint, len);
}

pub fn bytes(self: *const Self) []const u8 {
    return self.utf8_buf[0..self.utf8_len];
}

test "Cell handles ASCII and Japanese UTF-8" {
    var ascii = Self{};
    ascii.setCh("A");
    try std.testing.expectEqual(@as(u3, 1), ascii.utf8_len);
    try std.testing.expectEqualSlices(u8, "A", ascii.bytes());
    try std.testing.expect(!ascii.is_wide);

    var jp = Self{};
    jp.setCh("日");
    try std.testing.expectEqual(@as(u3, 3), jp.utf8_len);
    try std.testing.expectEqualSlices(u8, "日", jp.bytes());
    try std.testing.expect(jp.is_wide);
}
