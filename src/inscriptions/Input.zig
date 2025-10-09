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
h: usize = 1,
w: usize = 0, // this value is set in `inscribe`
x: usize = 0, // this value is set in `inscribe`
y: usize = 0, // this value is set in `inscribe`

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

/// Draw the input component to a `Runestone` at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void {
    self.x = x;
    self.y = y;

    if (self.hidden) {
        self.w = 0;
        self.h = 0;
        return;
    }

    self.w = self.buffer.items.len + 2 * @as(usize, @intFromBool(self.border));
    self.h = 1 + 2 * @as(usize, @intFromBool(self.border));

    var render_x = x + @intFromBool(self.border);
    const render_y = y + @intFromBool(self.border);

    var cursor_style = self.style.text;
    cursor_style.bg = .{ .xterm = .white };

    // TODO: Add wrap support
    if (self.buffer.items.len == 0) {
        if (self.focused) {
            try stone.addText(render_x, render_y, " ", cursor_style);
        } else {
            try stone.addText(render_x, render_y, self.placeholder, self.style.placeholder);
        }
    } else {
        // If cursor is at the end, just render normally plus the cursor
        if (self.cursor == self.buffer.items.len) {
            try stone.addText(render_x, render_y, self.buffer.items, self.style.text);
            try stone.addText(render_x + self.buffer.items.len, render_y, " ", cursor_style);
        } else {
            // Render before cursor
            if (self.cursor > 0) {
                try stone.addText(render_x, render_y, self.buffer.items[0..self.cursor], self.style.text);
                render_x += self.cursor;
            }

            // Render cursor itself
            try stone.addText(render_x, render_y, self.buffer.items[self.cursor .. self.cursor + 1], cursor_style);
            render_x += 1;

            // Render after cursor
            if (self.cursor + 1 < self.buffer.items.len) {
                try stone.addText(render_x, render_y, self.buffer.items[self.cursor + 1 ..], self.style.text);
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
