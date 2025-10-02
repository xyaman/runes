const std = @import("std");

pub fn isWideCharacter(bytes: []const u8, len: u3) bool {
    const ch = switch (len) {
        1 => bytes[0],
        2 => std.unicode.utf8Decode2(bytes[0..2].*) catch unreachable,
        3 => std.unicode.utf8Decode3(bytes[0..3].*) catch unreachable,
        4 => std.unicode.utf8Decode4(bytes[0..4].*) catch unreachable,
        else => unreachable,
    };

    // Control characters have zero width
    if (ch < 0x20 or (ch >= 0x7F and ch < 0xA0)) {
        return false;
    }

    // ASCII characters are narrow
    if (ch < 0x7F) {
        return false;
    }

    // Wide character ranges (CJK, emojis, etc.)
    return (ch >= 0x1100 and ch <= 0x115F) or // Hangul Jamo
        (ch >= 0x2E80 and ch <= 0x2EFF) or // CJK Radicals
        (ch >= 0x2F00 and ch <= 0x2FDF) or // Kangxi Radicals
        (ch >= 0x3000 and ch <= 0x303F) or // CJK Symbols
        (ch >= 0x3040 and ch <= 0x309F) or // Hiragana
        (ch >= 0x30A0 and ch <= 0x30FF) or // Katakana
        (ch >= 0x3100 and ch <= 0x312F) or // Bopomofo
        (ch >= 0x3130 and ch <= 0x318F) or // Hangul Compatibility
        (ch >= 0x3400 and ch <= 0x4DBF) or // CJK Extension A
        (ch >= 0x4E00 and ch <= 0x9FFF) or // CJK Unified Ideographs
        (ch >= 0xAC00 and ch <= 0xD7AF) or // Hangul Syllables
        (ch >= 0xF900 and ch <= 0xFAFF) or // CJK Compatibility
        (ch >= 0xFF00 and ch <= 0xFFEF) or // Fullwidth Forms
        (ch >= 0x1F000 and ch <= 0x1F9FF) or // Emojis
        (ch >= 0x20000 and ch <= 0x2A6DF) or // CJK Extension B
        (ch >= 0x2A700 and ch <= 0x2B73F) or // CJK Extension C
        (ch >= 0x2B740 and ch <= 0x2B81F) or // CJK Extension D
        (ch >= 0x2B820 and ch <= 0x2CEAF) or // CJK Extension E
        (ch >= 0x2CEB0 and ch <= 0x2EBEF); // CJK Extension F
}
