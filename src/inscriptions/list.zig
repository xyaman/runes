const std = @import("std");
const mibu = @import("mibu");

const ui = @import("ui.zig");

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
        if (!@hasField(T, "label") and !@hasDecl(T, "inscribe")) {
            @compileError("List(T): type " ++ @typeName(T) ++ " must provide either a field `label: []const u8` or a function `inscribe(...)`.");
        }
    }

    return struct {
        const Self = @This();

        // geometry
        h: usize = 0,
        w: usize = 0, // this value is set in `inscribe`
        x: usize = 0, // this value is set in `inscribe`
        y: usize = 0, // this value is set in `inscribe`
        max_h: usize,

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
            max_height: usize = 10,
        };

        /// Create a new List
        pub fn init(items: []T, options: InitOptions) Self {
            return Self{
                .items = items,
                .selected = 0,
                .first_visible = 0,
                .max_h = options.max_height,
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
            if (self.selected >= self.first_visible + self.max_h) self.first_visible = self.selected - self.max_h + 1;
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

            var offset: usize = 0;
            if (self.title) |title| {
                // avoid adding title if the title is in the border
                if (!self.border) {
                    try stone.addText(base_x, base_y, title, .{});
                    self.w = @max(title.len, self.w);
                    offset += 1;
                }
            }

            for (0..self.max_h) |row| {
                const idx = self.first_visible + row;
                if (idx >= self.items.len) break;

                var item = self.items[idx];
                const len = blk: {
                    if (@hasDecl(T, "inscribe")) {
                        var artisan = Artisan{ .x = base_x, .y = base_y + row + offset, .stone = stone };
                        break :blk try item.inscribe(idx, self.selected == idx, &artisan);
                    } else if (@hasField(T, "label")) {
                        // Default, simple implementation
                        var prefix: []const u8 = "  ";
                        if (idx == self.selected) prefix = "> ";

                        const style: Rune.Style = .{
                            .fg = if (idx == self.selected) .{ .xterm = .red } else .default,
                        };

                        break :blk try stone.addTextFmt(base_x, base_y + row + offset, "{s} {d}. {s}", .{ prefix, idx + 1, item.label }, style);
                    } else {
                        // already compile-error-checked above
                        unreachable;
                    }
                };

                const border_w = 2 * @as(usize, @intFromBool(self.border));
                self.w = @max(len + border_w + 2 * self.margin.x, self.w);
                self.h = offset + row + 1 + border_w + 2 * self.margin.y;
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
                    if (!(m.x >= self.x and m.x <= self.x + self.w and m.y >= self.y and m.y <= self.y + self.h)) return false;

                    // find the selected item
                    for (0..self.h) |row| {
                        const idx = self.first_visible + row;
                        if (idx >= self.items.len) break;

                        // + 1: 0-index array
                        // + 1: rows starts at 1 (mibu)
                        if (m.y == self.y + row + 1) {
                            self.selected = self.first_visible + row;
                            return true;
                        }

                        // if (m.y == self.y + row + self.margin.y + @intFromBool(self.border)) {
                        //     self.selected = self.first_visible + row;
                        //     return true;
                        // }
                    }
                },
                else => return false,
            }

            return true;
        }
    };
}
