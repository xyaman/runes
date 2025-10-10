const std = @import("std");
const Runestone = @import("../Runestone.zig");

pub const Size = struct { w: usize, h: usize };

pub const Constraints = struct {
    min_w: usize = 0,
    max_w: usize = std.math.maxInt(usize),
    min_h: usize = 0,
    max_h: usize = std.math.maxInt(usize),
};

pub const Rect = struct {
    x: usize = 0,
    y: usize = 0,
    w: usize = 0,
    h: usize = 0,
};

pub const Margin = struct {
    x: usize = 0,
    y: usize = 0,
};

// https://github.com/gdamore/tcell/blob/master/runes.go
pub const chars = struct {
    const DArrow = '↓';
    const LArrow = '←';
    const RArrow = '→';
    const UArrow = '↑';
    const Bullet = '·';

    const Board = '░';
    const CkBoard = '▒';
    const Degree = '°';
    const Diamond = '◆';
    const GEqual = '≥';
    const Pi = 'π';
    const HLine = '─';
    const Lantern = '§';

    const Plus = '┼';
    const LEqual = '≤';
    const LLCorner = '└';
    const LRCorner = '┘';
    const NEqual = '≠';
    const PlMinus = '±';
    const S1 = '⎺';
    const S3 = '⎻';
    const S7 = '⎼';
    const S9 = '⎽';

    const Block = '█';
    const TTee = '┬';
    const RTee = '┤';
    const LTee = '├';

    const BTee = '┴';
    const ULCorner = '┌';
    const URCorner = '┐';

    const VLine = '│';
};

// reference: https://github.com/akarpovskii/tuile/blob/main/src/widgets/border.zig
pub const BorderType = enum {
    simple,
    solid,
    rounded,
    double,
    thick,
};

// reference: https://github.com/akarpovskii/tuile/blob/main/src/widgets/border.zig
pub const BorderCharacters = struct {
    top: []const u8,
    bottom: []const u8,
    left: []const u8,
    right: []const u8,
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,

    pub fn fromType(border: BorderType) BorderCharacters {
        return switch (border) {
            .simple => .{
                .top = "-",
                .bottom = "-",
                .left = "|",
                .right = "|",
                .top_left = "+",
                .top_right = "+",
                .bottom_left = "+",
                .bottom_right = "+",
            },
            .solid => .{
                .top = "─",
                .bottom = "─",
                .left = "│",
                .right = "│",
                .top_left = "┌",
                .top_right = "┐",
                .bottom_left = "└",
                .bottom_right = "┘",
            },
            .rounded => .{
                .top = "─",
                .bottom = "─",
                .left = "│",
                .right = "│",
                .top_left = "╭",
                .top_right = "╮",
                .bottom_left = "╰",
                .bottom_right = "╯",
            },
            .double => .{
                .top = "═",
                .bottom = "═",
                .left = "║",
                .right = "║",
                .top_left = "╔",
                .top_right = "╗",
                .bottom_left = "╚",
                .bottom_right = "╝",
            },

            .thick => .{
                .top = "━",
                .bottom = "━",
                .left = "┃",
                .right = "┃",
                .top_left = "┏",
                .top_right = "┓",
                .bottom_left = "┗",
                .bottom_right = "┛",
            },
        };
    }
};

pub fn drawWithBorder(inscription: anytype, stone: *Runestone, title: ?[]const u8) !void {
    // Measure inner component
    const w = inscription.computed_rect.w;
    const h = inscription.computed_rect.h;
    const x = inscription.computed_rect.x + inscription.margin.x;
    const y = inscription.computed_rect.y + inscription.margin.y;
    const z_index = inscription.z_index;

    if (w < 3 or h < 3) return error.SizeTooSmall;

    // Draw top
    if (title) |t| {
        try stone.addText(x + 1, y, t, z_index, .{});
        for (t.len + 2..w) |i| {
            try stone.addText(x + i, y, "─", z_index, .{});
        }
    } else {
        for (0..w) |i| {
            try stone.addText(x + i, y, "─", z_index, .{});
        }
    }

    // Draw bottom border
    for (0..w) |i| {
        try stone.addText(x + i, y + h - 1, "─", z_index, .{});
    }

    // Draw left and right borders
    for (1..h - 1) |i| {
        try stone.addText(x, y + i, "│", z_index, .{});
        try stone.addText(x + w, y + i, "│", z_index, .{});
    }

    // Draw corners
    try stone.addText(x, y, "┌", z_index, .{});
    try stone.addText(x + w, y, "┐", z_index, .{});
    try stone.addText(x, y + h - 1, "└", z_index, .{});
    try stone.addText(x + w, y + h - 1, "┘", z_index, .{});
}
