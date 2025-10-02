const std = @import("std");
const mibu = @import("mibu");

const common = @import("common.zig");
const Inscription = @import("Inscription.zig");

const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

items: [][]const u8,
selected: usize = 0,
first_visible: usize = 0,
height: usize,

/// Create a new Self
pub fn init(items: [][]const u8, height: usize) Self {
    return Self{
        .items = items,
        .selected = 0,
        .first_visible = 0,
        .height = height,
    };
}

pub fn inscription(self: *Self) Inscription {
    return .{
        .ptr = self,
        .vtable = &.{
            .measure = measure,
            .inscribe = inscribe,
            .handleInput = handleInput,
        },
    };
}

/// Move selection up
pub fn up(self: *Self) void {
    if (self.selected > 0) self.selected -= 1;
    if (self.selected < self.first_visible) self.first_visible = self.selected;
}

/// Move selection down
pub fn down(self: *Self) void {
    if (self.selected + 1 < self.items.len) self.selected += 1;
    if (self.selected >= self.first_visible + self.height) self.first_visible = self.selected - self.height + 1;
}

/// Draw the self to the Runestone at (x, y)
pub fn inscribe(ctx: *anyopaque, stone: *Runestone, x: usize, y: usize) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    for (0..self.height) |row| {
        const idx = self.first_visible + row;
        if (idx >= self.items.len) break;

        const item = self.items[idx];

        const style: Rune.Style = .{
            .fg = if (idx == self.selected) .{ .xterm = .red } else .default,
        };

        var prefix = "  ";
        if (idx == self.selected) prefix = "> ";
        try stone.addTextFmt(x, y + row, "{s} {d}. {s}", .{ prefix, idx + 1, item }, style);
    }
}

pub fn measure(ctx: *anyopaque) common.Size {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return .{
        .h = self.height,
        .w = 30, // todo: rename
    };
}

pub fn handleInput(ctx: *anyopaque, event: mibu.events.Event) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    switch (event) {
        .key => |k| switch (k.code) {
            .up => self.up(),
            .down => self.down(),
            .char => |c| switch (c) {
                'j' => self.down(),
                'k' => self.up(),
                else => {},
            },
            else => {},
        },
        else => {},
    }
}
