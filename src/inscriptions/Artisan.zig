//! `Artisan` is a scoped text-writing controller for a `Runestone`.
//!
//! It acts as a wrapper around a `Runestone` instance, allowing text to be written
//! at a specific `(x, y)` position with a given `Rune.Style`. `Artisan` is designed
//! for controlled, nested contexts such as tables, lists, or other structured elements,
//! where the caller manages the cursor position.
//!
//! By encapsulating the position and style, `Artisan` allows nested elements to write
//! text without directly managing the `Runestone` state.

const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

stone: *Runestone,

/// The X coordinate where text will be written. Should not be modified directly.
x: usize,

/// The Y coordinate where text will be written. Should not be modified directly.
y: usize,

/// Internal horizontal cursor offset. Do not modify directly.
x_offset: usize = 0,

/// Internal vertical cursor offset. Do not modify directly.
y_offset: usize = 0,

/// Writes formatted text at a fixed position and returns the number of characters written.
/// Designed for repeated horizontal writing; each call appends text to the right of the previous one.
/// Note: Only horizontal appending is supported; vertical positioning must be handled externally.
pub fn inscribe(self: *Self, comptime fmt: []const u8, args: anytype, style: Rune.Style) !usize {
    const len = try self.stone.addTextFmt(self.x, self.y, fmt, args, style);
    self.x_offset += len;
    return len;
}
