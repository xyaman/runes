const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");
const char_utils = @import("../char_utils.zig");

const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");
const Artisan = @import("Artisan.zig");

/// Provides a runes Inscription for browsing a general purpose list of items.
///
/// `T` must provide **either**:
///
/// * A `label: []const u8` field — a simple string to display for the item.
/// * An `inscribe` function — a custom renderer that can draw the item using an `Artisan`.
///   The function must have the following signature:
/// ```zig
/// pub fn inscribe(self: *T, index: usize, selected: bool, artisan: *runes.inscriptions.Artisan) !usize
/// ```
pub fn List(comptime T: type) type {

    // comptime validation of T (ListItem)
    comptime {
        if (!@hasField(T, "label") and !(@hasDecl(T, "inscribe") and @hasDecl(T, "measure"))) {
            @compileError("List(T): type " ++ @typeName(T) ++
                " must provide either a field `label: []const u8` or both a function `inscribe(...)` and a function `measure(...)`.");
        }
    }

    return struct {
        const Self = @This();

        // geometry
        rect: ui.Rect = .{ .h = 0, .w = 0, .x = 0, .y = 0 },
        computed_rect: ui.Rect = .{},
        z_index: usize = 0,

        // common ui
        hidden: bool = false,
        focused: bool = false,
        border: bool,
        margin: ui.Margin,

        items: []T,
        selected: usize = 0,
        first_visible: usize = 0,

        // ui
        title: ?[]const u8 = null,

        pub const InitOptions = struct {
            border: bool = false,
            margin: ui.Margin = .{},
        };

        /// Create a new List
        pub fn init(items: []T, options: InitOptions) Self {
            return Self{
                .items = items,
                .selected = 0,
                .first_visible = 0,
                .border = options.border,
                .margin = options.margin,
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
            if (self.selected >= self.first_visible + self.computed_rect.h) self.first_visible = self.selected - self.computed_rect.h + 1;
        }

        pub fn layout(self: *Self, contraints: ui.Constraints) ui.Size {
            const border_size: usize = @intCast(@intFromBool(self.border));

            // title has only extra height if border is null, otherwise the title is inside the border
            const title_h: usize = (1 - border_size) * @intFromBool(self.title != null);

            // 1. Calculate the component's ideal size based on its content.
            var base_width = self.rect.w;
            const base_height = if (self.rect.h > 0) self.rect.h else self.items.len + title_h;

            // auto width, use items max_width
            if (self.rect.w == 0) {
                var max_len: usize = 0;
                for (self.items) |*item| {
                    if (@hasField(T, "label")) {
                        // 4 => {d}. {prefix} (default list)
                        max_len = @max(max_len, 4 + char_utils.utf8Len(item.label));
                    } else {
                        max_len = @max(max_len, item.measure().w);
                    }
                }

                base_width = max_len;
            }

            const ideal_width = base_width + 2 * border_size;
            const ideal_height = base_height + 2 * border_size;

            // TODO: Implement text wrapping here.

            // 2. Clamp the ideal size to the constraints given by the parent.
            self.computed_rect.w = std.math.clamp(ideal_width, contraints.min_w, contraints.max_w);
            self.computed_rect.h = std.math.clamp(ideal_height, contraints.min_h, contraints.max_h);

            // 3. Return the final computed size so the parent can position this component.
            return .{
                .w = self.computed_rect.w,
                .h = self.computed_rect.h,
            };
        }

        /// Draw the self to the Runestone at (x, y)
        pub fn inscribe(self: *Self, stone: *Runestone, sx: usize, sy: usize) !void {
            self.computed_rect.x = sx;
            self.computed_rect.y = sy;

            if (self.hidden) {
                self.computed_rect.w = 0;
                self.computed_rect.h = 0;
                return;
            }

            const base_x = sx + self.margin.x + @intFromBool(self.border);
            const base_y = sy + self.margin.y + @intFromBool(self.border);

            var offset: usize = 0;
            if (self.title) |title| {
                // avoid adding title if the title is in the border
                if (!self.border) {
                    try stone.addText(base_x, base_y, title, self.z_index, .{});
                    // self.computed_rect.w = @max(title.len, self.rect.w);
                    offset += 1;
                }
            }

            for (0..self.computed_rect.h) |row| {
                const idx = self.first_visible + row;
                if (idx >= self.items.len) break;

                var item = self.items[idx];
                _ = blk: {
                    if (@hasDecl(T, "inscribe")) {
                        var artisan = Artisan{ .x = base_x, .y = base_y + row + offset, .z_index = self.z_index, .stone = stone };
                        break :blk try item.inscribe(idx, self.selected == idx, &artisan);
                    } else if (@hasField(T, "label")) {
                        // Default, simple implementation
                        var prefix: []const u8 = "  ";
                        if (idx == self.selected) prefix = "> ";

                        const style: Rune.Style = .{
                            .fg = if (idx == self.selected) .{ .xterm = .red } else .default,
                        };

                        break :blk try stone.addTextFmt(base_x, base_y + row + offset, "{s} {d}. {s}", .{ prefix, idx + 1, item.label }, self.z_index, style);
                    } else {
                        // already compile-error-checked above
                        unreachable;
                    }
                };

                // const border_w = 2 * @as(usize, @intFromBool(self.border));
                // self.rect.w = @max(len + border_w + 2 * self.margin.x, self.rect.w);
                // self.rect.h = offset + row + 1 + border_w + 2 * self.margin.y;
                // self.rect.h = self.h;
            }

            // render border
            if (self.border) try ui.drawWithBorder(self, stone, self.title);
        }

        pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
            if (self.hidden) return false;

            switch (event) {
                .key => |k| switch (k.code) {
                    .up => self.up(),
                    .down => self.down(),
                    .char => |c| switch (c) {
                        'j' => self.down(),
                        'k' => self.up(),
                        else => return false,
                    },
                    else => return false,
                },
                .mouse => |m| {
                    if (m.button != .left) return false;

                    const border_width = @intFromBool(self.border);
                    const title_height: u1 = if (self.border) 0 else @intFromBool(self.title != null);

                    // include border and title in coordinate bounds
                    const x_start = self.computed_rect.x + border_width;
                    const y_start = self.computed_rect.y + border_width + title_height;
                    const x_end = self.computed_rect.x + self.computed_rect.w + border_width;
                    const y_end = self.computed_rect.y + self.computed_rect.h + border_width + title_height;

                    // check mouse is inside component area including border + title
                    if (!(m.x >= x_start and m.x <= x_end and m.y >= y_start and m.y <= y_end)) return false;

                    // find the selected item
                    for (0..self.computed_rect.h) |row| {
                        const idx = self.first_visible + row;
                        if (idx >= self.items.len) break;

                        // mibu: m.y is 1-based index
                        if (m.y == y_start + row + 1) {
                            self.selected = self.first_visible + row;
                            return true;
                        }
                    }
                },
                else => return false,
            }

            return true;
        }
    };
}
