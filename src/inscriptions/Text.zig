//! Provides a `Runestone` inscription for displaying a general-purpose, read-only list of items.
//! Supports optional borders and custom text styling.

const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

// geometry
h: usize = 1,
w: usize = 0, // this value is set in `inscribe`
x: usize = 0, // this value is set in `inscribe`
y: usize = 0, // this value is set in `inscribe`
z_index: usize = 0,

// common ui
hidden: bool = false,
focused: bool = false,
border: bool,
margin: ui.Margin,

text: []const u8,
style: Rune.Style,

pub const InitOptions = struct {
    border: bool = false,
    margin: ui.Margin = .{},
    style: Rune.Style = .{},
};

/// Create a new List
pub fn init(text: []const u8, options: InitOptions) Self {
    return Self{
        .text = text,
        .style = options.style,
        .border = options.border,
        .margin = options.margin,
    };
}

/// Draw the self to the Runestone at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void {
    self.x = x;
    self.y = y;

    if (self.hidden) {
        self.w = 0;
        self.h = 0;
        return;
    }

    self.w = self.text.len + 2 * @as(usize, @intFromBool(self.border)) + 2 * self.margin.x;
    self.h = 1 + 2 * @as(usize, @intFromBool(self.border)) + 2 * self.margin.y;

    const render_x = x + @intFromBool(self.border) + self.margin.x;
    const render_y = y + @intFromBool(self.border) + self.margin.y;

    // TODO: Add wrap support for long text
    try stone.addText(render_x, render_y, self.text, self.z_index, self.style);

    if (self.border) try ui.drawWithBorder(self, stone, null);
}

pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    _ = self;
    _ = event;

    // const self: *Self = @ptrCast(@alignCast(ctx));
    return false;
}
