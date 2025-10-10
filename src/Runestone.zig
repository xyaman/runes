const std = @import("std");
const assert = std.debug.assert;
const mibu = @import("mibu");

const utils = @import("char_utils.zig");
const Rune = @import("Rune.zig");

/// Represents a drawable text buffer (like a double-buffered terminal canvas).
const Self = @This();

allocator: std.mem.Allocator,
buffers: [2][]Rune, // double buffering
curr_buffer: u2, // index of the active buffer

// Used for scrolling and draw from the initial cursor position
// the value is `0` when `Forge.Options.fullscreen` is `true`
y_offset: usize,

term_w: usize,
term_h: usize,
render_h: usize = 0,

/// Initialize a new Runestone with given width/height.
pub fn init(allocator: std.mem.Allocator, term_w: usize, term_h: usize, cursor_y: usize) !Self {
    const buffers = [_][]Rune{
        try allocator.alloc(Rune, term_w * term_h),
        try allocator.alloc(Rune, term_w * term_h),
    };

    @memset(buffers[0], .{});
    @memset(buffers[1], .{});

    return .{
        .allocator = allocator,
        .buffers = buffers,
        .curr_buffer = 0,
        .term_w = term_w,
        .term_h = term_h,
        .y_offset = cursor_y,
    };
}

pub fn resize(term_w: usize, term_h: usize) !void {
    _ = term_w;
    _ = term_h;
}

/// Free resources.
pub fn deinit(self: *Self) void {
    self.allocator.free(self.buffers[0]);
    self.allocator.free(self.buffers[1]);
}

/// Adds text to the runestone at (sx, sy).
/// Currently stops at edges (no wrapping).
pub fn addText(self: *Self, sx: usize, sy: usize, text: []const u8, z_index: usize, style: Rune.Style) !void {
    const buf = self.buffers[self.curr_buffer];
    var utf8 = (try std.unicode.Utf8View.init(text)).iterator();
    var x: usize = sx;

    // TODO: check
    while (utf8.nextCodepointSlice()) |codepoint| : (x += 1) {
        if (x >= self.term_w) break;
        if (sy * self.term_w + x >= buf.len) break;

        const len = std.unicode.utf8ByteSequenceLength(codepoint[0]) catch @panic("utf8ByteSequenceLength");

        // if the codepoint is wide and the space is less than 2 characters, stop writing
        // TODO: should we clean the rune if it was continuous?
        const is_wide = utils.isWideCharacter(codepoint, len);
        if (is_wide and x + 1 >= self.term_w) break;

        var rune = &buf[sy * self.term_w + x];

        // return if current rune z-index is bigger
        if (rune.z_index > z_index) continue;

        // Overwriting continuation cell: clear the wide rune before it
        // TODO: is `*` neccessary
        if (rune.*.is_continuation) {
            assert(x > 0);

            const prev_rune = &buf[sy * self.term_w + x - 1];
            assert(prev_rune.*.is_wide);
            prev_rune.* = .{};
        }

        // Overwriting start of a wide rune: clear continuation
        // TODO: is `*` neccessary
        if (rune.*.is_wide) {
            assert(x + 1 < buf.len);
            const next_rune = &buf[sy * self.term_w + x + 1];

            assert(next_rune.*.is_continuation);
            next_rune.* = .{};
        }

        rune.setCh(codepoint);
        rune.style = style;

        // If wide rune: mark continuation cell
        if (rune.is_wide) {
            const next_rune = &buf[sy * self.term_w + x + 1];
            next_rune.*.is_continuation = true;
            x += 1;
        }
    }

    self.render_h = @max(self.render_h, sy + 1);
}

pub fn addTextFmt(
    self: *Self,
    sx: usize,
    sy: usize,
    comptime fmt: []const u8,
    args: anytype,
    z_index: usize,
    style: Rune.Style,
) !usize {
    // local stack buffer: temporary text storage for this one call
    var buf: [256]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, fmt, args);

    // Safe because addText copies into rune cells
    try self.addText(sx, sy, text, z_index, style);
    return text.len;
}

/// Draws the canvas/runestone by diffing against the previous buffer.
/// Only changed cells/runes are written to the output.
pub fn engrave(self: *Self, out: *std.Io.Writer) !void {
    const buf = self.buffers[self.curr_buffer];
    const prev = self.buffers[1 - self.curr_buffer];

    try mibu.color.resetAll(out);
    var curr_render_style: Rune.Style = .{};

    var y: usize = 0;

    // scroll if the next render will be out of screen
    if (self.y_offset != 0 and self.render_h + self.y_offset > self.term_h) {
        const lines_to_scroll = self.render_h + self.y_offset - self.term_h;
        try mibu.scroll.up(out, lines_to_scroll);
        self.y_offset -= lines_to_scroll;
    }

    while (y < self.term_h and y < self.render_h) : (y += 1) {
        var x: usize = 0;
        while (x < self.term_w) : (x += 1) {
            const i = y * self.term_w + x;

            // print/replace the rune if anything changed
            if (!std.meta.eql(buf[i], prev[i])) {
                try mibu.cursor.goTo(out, x + 1, self.y_offset + y + 1);

                // same buffer one rune before
                if (!curr_render_style.equals(buf[i].style)) {
                    try applyStyle(out, buf[i].style, curr_render_style);
                    curr_render_style = buf[i].style;
                }

                try out.print("{s}", .{buf[i].bytes()});
            }
        }
    }

    // always set the cursor at the bottom (when the programs exists is below
    // the rendered content => feels more natural)
    try mibu.cursor.goTo(out, 1, self.y_offset + y + 1);

    // Swap buffers and clear new active buffer
    self.curr_buffer = 1 - self.curr_buffer;
    @memset(self.buffers[self.curr_buffer], .{});
}

// todo: only outputs the style if it changes based on the previous rune
fn applyStyle(out: *std.Io.Writer, new: Rune.Style, prev: Rune.Style) !void {

    // no need to re-print values if the previous (x-1) rune is the same
    // note: don't confuse with previous value of the rune (last render)
    //if (new.equals(prev)) return;

    // Compare attributes individually and emit CSI if they changed
    if (new.attr.italic != prev.attr.italic) try mibu.style.italic(out, new.attr.italic);
    if (new.attr.bold != prev.attr.bold) try mibu.style.bold(out, new.attr.bold);
    if (new.attr.underline != prev.attr.underline) try mibu.style.underline(out, new.attr.underline);
    if (new.attr.reverse != prev.attr.reverse) try mibu.style.reverse(out, new.attr.reverse);
    if (new.attr.blink != prev.attr.blink) try mibu.style.blinking(out, new.attr.blink);
    if (new.attr.strikethrough != prev.attr.strikethrough) try mibu.style.strikethrough(out, new.attr.strikethrough);

    if (!std.meta.eql(new.bg, prev.bg)) switch (new.bg) {
        .xterm => try mibu.color.bg256(out, new.bg.xterm),
        else => try out.print("\x1b[49m", .{}),
    };

    if (!std.meta.eql(new.fg, prev.fg)) switch (new.fg) {
        .xterm => try mibu.color.fg256(out, new.fg.xterm),
        else => try out.print("\x1b[39m", .{}),
    };
}
