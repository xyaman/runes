//! Provides a text input component for browsing and editing a general-purpose list of items.
//! Handles UTF-8 input, cursor movement, simple word-wise navigation, and deletion.

const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");
const char_utils = @import("../char_utils.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

allocator: std.mem.Allocator,
buffer: std.ArrayListUnmanaged(u8) = .empty,

cursor: usize = 0,

// geometry
rect: ui.Rect = .{ .h = 1 },
computed_rect: ui.Rect = .{},
z_index: usize = 0,

// common ui
hidden: bool = false,
focused: bool = false,
border: bool,
margin: ui.Margin,

placeholder: []const u8 = "<input>",

style: InputStyle,

pub const InputStyle = struct {
    text: Rune.Style = .{},
    placeholder: Rune.Style = .{ .fg = .{ .xterm = .grey_50 } },
};

pub const InitOptions = struct {
    border: bool = false,
    margin: ui.Margin = .{},
    style: InputStyle = .{},
};

/// Initialize a new Input component
/// Don't forget to call `Input.deinit()`
pub fn init(allocator: std.mem.Allocator, options: InitOptions) Self {
    return Self{
        .allocator = allocator,
        .style = options.style,
        .border = options.border,
        .margin = options.margin,
    };
}

/// Deallocate internal buffer
pub fn deinit(self: *Self) void {
    self.buffer.deinit(self.allocator);
}

/// Set the text content (removes current content)
pub fn setText(self: *Self, allocator: std.mem.Allocator, s: []const u8) !void {
    self.buffer.deinit(self.allocator);
    self.buffer = try std.ArrayListUnmanaged(u8).initCapacity(allocator, s.len);
    try self.buffer.appendSlice(allocator, s);
    self.cursor = self.buffer.items.len;
}

/// Clear the text but retain buffer capacity
pub fn clearRetainingCapacity(self: *Self) void {
    self.buffer.clearRetainingCapacity();
    self.cursor = 0;
}

/// Clear the text and free buffer memory
pub fn clearAndFree(self: *Self) void {
    self.buffer.clearAndFree(self.allocator);
    self.cursor = 0;
}

pub fn layout(self: *Self, constraints: ui.Constraints) ui.Size {
    const border_size: usize = @intCast(@intFromBool(self.border));

    // 1. Calculate the component's ideal size based on its content.
    const base_width = if (self.rect.w > 0) self.rect.w else char_utils.utf8Len(self.buffer.items);

    const ideal_width = base_width + 2 * border_size;
    const ideal_height = self.rect.h + 2 * border_size;

    // 2. Clamp the ideal size to the constraints given by the parent.
    self.computed_rect.w = std.math.clamp(ideal_width, constraints.min_w, constraints.max_w);
    self.computed_rect.h = ideal_height;

    // 3. Return the final computed size so the parent can position this component.
    return .{
        .w = self.computed_rect.w,
        .h = self.computed_rect.h,
    };
}

/// Draw the input component to a `Runestone` at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void {
    // if it is outside layout manager component like `Stack`, the computed rect
    // will be the default, we will override that
    if (std.meta.eql(self.rect, ui.Rect{})) {
        self.computed_rect = self.rect;
    }

    self.computed_rect.x = x;
    self.computed_rect.y = y;

    if (self.hidden) {
        return;
    }

    var render_x = x + @intFromBool(self.border) + self.margin.x;
    const render_y = y + @intFromBool(self.border) + self.margin.y;

    var cursor_style = self.style.text;
    cursor_style.bg = .{ .xterm = .white };

    // TODO: Add wrap support
    if (self.buffer.items.len == 0) {
        if (self.focused) {
            try stone.addText(render_x, render_y, " ", self.z_index, cursor_style);
        } else {
            try stone.addText(render_x, render_y, self.placeholder, self.z_index, self.style.placeholder);
        }
    } else {
        // If cursor is at the end, just render normally plus the cursor
        if (self.cursor == self.buffer.items.len) {
            try stone.addText(render_x, render_y, self.buffer.items, self.z_index, self.style.text);
            try stone.addText(render_x + self.buffer.items.len, render_y, " ", self.z_index, cursor_style);
        } else {
            // Render before cursor
            if (self.cursor > 0) {
                try stone.addText(render_x, render_y, self.buffer.items[0..self.cursor], self.z_index, self.style.text);
                render_x += self.cursor;
            }

            // Render cursor itself
            try stone.addText(render_x, render_y, self.buffer.items[self.cursor .. self.cursor + 1], self.z_index, cursor_style);
            render_x += 1;

            // Render after cursor
            if (self.cursor + 1 < self.buffer.items.len) {
                try stone.addText(render_x, render_y, self.buffer.items[self.cursor + 1 ..], self.z_index, self.style.text);
            }
        }
    }

    if (self.border) try ui.drawWithBorder(self, stone, null);
}

/// Handle user input events (UTF-8 characters, navigation, deletion)
pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    if (self.hidden) return false;

    switch (event) {
        .key => |k| switch (k.code) {
            .char => |c| {
                var char = c;

                // handle remove word
                if (char == 'w' and k.mods.ctrl) {
                    var i = self.cursor;

                    // find start of the previous word
                    // skip any trailing spaces first
                    // then skip the word itself
                    while (i > 0 and self.buffer.items[i - 1] == ' ') : (i -= 1) {}
                    while (i > 0 and self.buffer.items[i - 1] != ' ') : (i -= 1) {}

                    const delete_len = self.cursor - i;
                    if (delete_len > 0) {
                        // shift the rest of the buffer left
                        std.mem.copyBackwards(u8, self.buffer.items[i .. self.buffer.items.len - delete_len], self.buffer.items[self.cursor..self.buffer.items.len]);
                        self.buffer.items.len -= delete_len;
                        self.cursor = i;
                    }

                    return true;
                }

                // if shift is true: lowercase => uppercase
                if (k.mods.shift) {
                    char -= 32;
                }

                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(char, &buf) catch return false;
                const text = buf[0..len];

                if (self.cursor < self.buffer.items.len) {
                    self.buffer.insertSlice(self.allocator, self.cursor, text) catch return false;
                } else {
                    self.buffer.appendSlice(self.allocator, text) catch return false;
                }

                self.cursor += len;
                return true;
            },
            .backspace => {
                if (self.cursor == 0) return false;

                var i = self.cursor - 1;

                // UTF-8 continuation bytes are 0b10xxxxxx (0x80..0xBF)
                // break when we find a non-continuation byte (the start of utf-8 codepoint)
                // works with ascii too, because we always move -1 the cursor at least once
                while (i > 0 and (self.buffer.items[i] & 0b1100_0000 == 0b1000_0000)) : (i -= 1) {}

                const cp_start = i;
                const cp_len = self.cursor - cp_start;

                std.mem.copyBackwards(u8, self.buffer.items[cp_start .. self.buffer.items.len - cp_len], self.buffer.items[self.cursor..self.buffer.items.len]);
                self.buffer.items.len -= cp_len;
                self.cursor = cp_start;

                return true;
            },
            .right => {
                if (k.mods.ctrl) {
                    // ctrl: move to the start of the next word
                    var i = self.cursor;
                    const len = self.buffer.items.len;

                    // Skip current word if in middle of one
                    // Skip any spaces
                    while (i < len and self.buffer.items[i] != ' ') : (i += 1) {}
                    while (i < len and self.buffer.items[i] == ' ') : (i += 1) {}
                    self.cursor = i;
                } else if (self.cursor < self.buffer.items.len) {
                    self.cursor += 1;
                }
                return true;
            },
            .left => {
                if (k.mods.ctrl) {
                    // ctrl: move to the start of the previous word
                    var i = self.cursor;
                    // Skip any spaces before the cursor
                    // Skip the word itself
                    while (i > 0 and self.buffer.items[i - 1] == ' ') : (i -= 1) {}
                    while (i > 0 and self.buffer.items[i - 1] != ' ') : (i -= 1) {}
                    self.cursor = i;
                } else if (self.cursor > 0) {
                    self.cursor -= 1;
                }
                return true;
            },
            else => {},
        },
        else => {},
    }

    return false;
}

test "handleInput adds a unicode character" {
    const Input = Self;

    const gpa = std.testing.allocator;
    var list = Input.init(gpa, .{});

    defer list.deinit();

    const event = mibu.events.Event{
        .key = .{
            .code = .{ .char = '日' },
            .mods = .{},
        },
    };

    const handled = try list.handleInput(event);
    try std.testing.expect(handled);

    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode('日', &buf) catch 0;
    try std.testing.expect(list.buffer.items.len == len); // length in bytes
    try std.testing.expectEqual(list.buffer.items[0], buf[0]);
}

test "handleInput backspace removes a character" {
    const Input = Self;

    const gpa = std.testing.allocator;
    var list = Input.init(gpa, .{});
    defer list.deinit();

    try list.setText(gpa, "a日b"); // initial string

    // move cursor to end
    list.cursor = list.buffer.items.len;

    // remove last char 'b'
    const backspace_event = mibu.events.Event{
        .key = .{
            .code = .backspace,
            .mods = .{},
        },
    };

    var handled = try list.handleInput(backspace_event);
    try std.testing.expect(handled);

    try std.testing.expectEqualStrings(list.buffer.items, "a日");

    // remove Unicode char '日'
    handled = try list.handleInput(backspace_event);
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings(list.buffer.items, "a");

    // remove last char 'a'
    handled = try list.handleInput(backspace_event);
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings(list.buffer.items, "");

    // backspace at start does nothing
    handled = try list.handleInput(backspace_event);
    try std.testing.expect(!handled);
}
