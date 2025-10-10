//! Provides a `Runestone` inscription for displaying a general-purpose, read-only list of items.
//! Supports optional borders and custom text styling.

const std = @import("std");
const mibu = @import("mibu");

const char_utils = @import("../char_utils.zig");
const ui = @import("ui.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

// geometry
rect: ui.Rect = .{ .h = 1, .w = 0, .x = 0, .y = 0 },
computed_rect: ui.Rect = .{},
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

/// TODO: Layout modifies computed rect??
/// is this ok?
pub fn layout(self: *Self, constraints: ui.Constraints) ui.Size {
    const border_size: usize = @intCast(@intFromBool(self.border));

    // 1. Calculate the component's ideal size based on its content.
    const base_width = if (self.rect.w > 0) self.rect.w else char_utils.utf8Len(self.text);

    const ideal_width = base_width + 2 * border_size;
    const ideal_height = self.rect.h + 2 * border_size;

    // TODO: Implement text wrapping here.

    // 2. Clamp the ideal size to the constraints given by the parent.
    self.computed_rect.w = std.math.clamp(ideal_width, constraints.min_w, constraints.max_w);
    self.computed_rect.h = ideal_height;

    // 3. Return the final computed size so the parent can position this component.
    return .{
        .w = self.computed_rect.w,
        .h = self.computed_rect.h,
    };
}

/// Draw the self to the Runestone at (x, y)
pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void {
    // if it is outside layout manager component like `Stack`, the computed rect
    // will be the default, we will override that
    if (std.meta.eql(self.rect, ui.Rect{})) {
        self.computed_rect = self.rect;
    }

    // store the final position of the component (useful for event handling)
    self.computed_rect.x = x;
    self.computed_rect.y = y;

    if (self.hidden) return;

    // TODO: revisar bordes
    const render_x = x + @intFromBool(self.border) + self.margin.x;
    const render_y = y + @intFromBool(self.border) + self.margin.y;

    const max_chars = self.computed_rect.w;
    const total_chars = char_utils.utf8Len(self.text);

    // if the full text fits, draw and return
    if (total_chars <= max_chars) {
        // TODO: Add wrap support for long text
        try stone.addText(render_x, render_y, self.text, self.z_index, self.style);
        if (self.border) try ui.drawWithBorder(self, stone, null);
        return;
    }

    // otherwise we show (max_chars - 1) codeponts and add "…" at the end
    const visible_chars = max_chars - 1; // may be 0 if max_chars == 1
    var utf8 = (try std.unicode.Utf8View.init(self.text)).iterator();
    var cursor: usize = 0;
    var seen: usize = 0;
    while (utf8.nextCodepointSlice()) |cp| {
        if (seen + 1 >= visible_chars) break;
        cursor += cp.len;
        seen += 1;
    }

    // draw the visible prefix (if any)
    if (cursor > 0) {
        try stone.addText(render_x, render_y, self.text[0..cursor], self.z_index, self.style);
    }

    // draw ellipsis in the final column
    try stone.addText(render_x + seen, render_y, "…", self.z_index, self.style);

    if (self.border) try ui.drawWithBorder(self, stone, null);
}

pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    _ = self;
    _ = event;

    // const self: *Self = @ptrCast(@alignCast(ctx));
    return false;
}
