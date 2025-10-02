//! Provides a runes Inscription for browsing a general purpose list of items.

const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

h: usize = 1,
w: usize = 0, // this value is set in `inscribe`
x: usize = 0, // this value is set in `inscribe`
y: usize = 0, // this value is set in `inscribe`

text: []const u8,
style: Rune.Style,
border: bool,

/// Create a new List
pub fn init(text: []const u8, style: Rune.Style, border: bool) Self {
    return Self{ .text = text, .style = style, .border = border };
}

/// Draw the self to the Runestone at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void {
    self.x = x;
    self.y = y;
    self.w = self.text.len + 2 * @as(usize, @intFromBool(self.border));
    self.h = 1 + 2 * @as(usize, @intFromBool(self.border));

    const render_x = x + @intFromBool(self.border);
    const render_y = y + @intFromBool(self.border);
    // TODO: Add wrap support
    try stone.addText(render_x, render_y, self.text, self.style);

    if (self.border) try ui.drawWithBorder(self, stone, null);
}

pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    _ = self;
    _ = event;

    // const self: *Self = @ptrCast(@alignCast(ctx));
    return false;
}
