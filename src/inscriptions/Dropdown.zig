//! Provides a `Runestone` inscription for displaying a general-purpose, read-only list of items.
//! Supports optional borders and custom text styling.

const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");
const char_utils = @import("../char_utils.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

// geometry
h: usize = 1,
w: usize = 0, // this value is set in `inscribe`
x: usize = 0, // this value is set in `inscribe`
y: usize = 0, // this value is set in `inscribe`
z_index: usize = 1,

// common ui
hidden: bool = false,
focused: bool = false,
border: bool,
margin: ui.Margin,

// data
placeholder: []const u8 = "<dropdown>",
options: [][]const u8,
selected: ?usize = null,
open: bool = false,

pub const InitOptions = struct {
    border: bool = false,
    margin: ui.Margin = .{},
};

pub fn init(options: [][]const u8, opts: InitOptions) Self {
    return Self{
        .options = options,
        .selected = 0,
        .open = false,
        .border = opts.border,
        .margin = opts.margin,
    };
}

/// Move selection up
pub fn up(self: *Self) void {
    if (self.selected) |sel| {
        if (sel > 0) self.selected = sel - 1;
    } else {
        self.selected = 0;
    }
}

pub fn down(self: *Self) void {
    if (self.selected) |sel| {
        if (sel + 1 < self.options.len) self.selected = sel + 1;
    } else {
        self.selected = 0;
    }
}

/// Draw the self to the Runestone at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, sx: usize, sy: usize) !void {
    self.x = sx;
    self.y = sy;

    if (self.hidden) {
        self.w = 0;
        self.h = 0;
        return;
    }

    const base_x = sx + self.margin.x + @intFromBool(self.border);
    const base_y = sy + self.margin.y + @intFromBool(self.border);

    // --- main line
    const prefix = if (self.open) "▼ " else "▶ ";
    const len = std.unicode.utf8ByteSequenceLength(prefix[0]) catch 1;
    const prefix_len: usize = if (char_utils.isWideCharacter(prefix, len)) 2 else 1;

    const label = if (self.selected) |sel| self.options[sel] else self.placeholder;
    _ = try stone.addTextFmt(base_x, base_y, "{s}{s}", .{ prefix, label }, self.z_index, .{});

    var max_item_len = prefix_len + label.len;
    for (self.options) |o| max_item_len = @max(max_item_len, 2 + o.len); // TODO: 2 is the prefix

    self.w = max_item_len + 2 * @as(usize, @intFromBool(self.border));
    self.h = 1 + 2 * @as(usize, @intFromBool(self.border));

    // --- options list
    if (self.open) {
        var offset: usize = 1;
        for (self.options, 0..) |opt, idx| {
            const mark = if (self.selected == idx) "> " else "  ";
            _ = try stone.addTextFmt(base_x, base_y + offset, "{s}{s}", .{ mark, opt }, self.z_index, .{});
            offset += 1;
            self.h += 1;
        }
    }

    if (self.border) try ui.drawWithBorder(self, stone, null);
}

/// Handle keyboard/mouse input
pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    if (self.hidden) return false;

    switch (event) {
        .key => |k| switch (k.code) {
            .enter => {
                self.open = !self.open;
                return true;
            },
            .up => if (self.open) self.up() else return false,
            .down => if (self.open) self.down() else return false,
            .esc => if (self.open) {
                self.open = false;
            },
            .char => |c| switch (c) {
                'j' => if (self.open) self.down() else return false,
                'k' => if (self.open) self.up() else return false,
                else => return false,
            },
            else => return false,
        },
        // TODO
        .mouse => |m| {
            if (m.button != .left) return false;
            if (!(m.x >= self.x and m.x <= self.x + self.w and m.y >= self.y and m.y <= self.y + self.h))
                return false;

            if (!self.open) {
                self.open = true;
                return true;
            } else {
                const idx = m.y - self.y - 1;
                if (idx < self.options.len) {
                    self.selected = idx;
                    self.open = false;
                    return true;
                }
            }
        },
        else => return false,
    }

    return false;
}
