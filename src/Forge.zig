const std = @import("std");
const mibu = @import("mibu");
const Runestone = @import("Runestone.zig");
const ui = @import("inscriptions/ui.zig");

const Self = @This();

allocator: std.mem.Allocator,
runestone: Runestone,
stdin_file: std.fs.File,
stdout: *std.Io.Writer,
raw_term: mibu.term.RawTerm,
options: Options = .{},
state: State = .{},

pub const Options = struct {
    alternate_screen: bool = false,
    clear_screen: bool = false,
    hide_cursor: bool = true,
    fullscreen: bool = false,
    mouse_support: bool = true,
};

pub const State = struct {
    y_offset: usize = 0,
};

pub fn init(allocator: std.mem.Allocator, in: std.fs.File, out: *std.Io.Writer, options: Options) !Self {
    // get terminal size
    const ws = try mibu.term.getSize(in.handle);

    var raw_term = try mibu.term.enableRawMode(in.handle);
    errdefer raw_term.disableRawMode() catch {};

    var cur_pos: mibu.cursor.Position = .{ .col = 0, .row = 0 };
    if (!options.fullscreen) {
        var reader = in.reader(&.{});
        cur_pos = try mibu.cursor.getPosition(&reader.interface, out);
        cur_pos.row -= 1;
    }

    const forge = Self{
        .allocator = allocator,
        .runestone = try Runestone.init(allocator, ws.width, ws.height, cur_pos.row),
        .stdin_file = in,
        .stdout = out,
        .raw_term = raw_term,
        .options = options,
        .state = .{ .y_offset = cur_pos.row },
    };

    if (options.alternate_screen) try mibu.term.enterAlternateScreen(forge.stdout);
    if (options.hide_cursor) try mibu.cursor.hide(forge.stdout);
    if (options.mouse_support) try out.print("{s}", .{mibu.utils.enable_mouse_tracking});
    return forge;
}

pub fn deinit(self: *Self) void {
    self.runestone.deinit();

    if (self.options.alternate_screen) mibu.term.exitAlternateScreen(self.stdout) catch {};
    if (self.options.hide_cursor) mibu.cursor.show(self.stdout) catch {};
    if (self.options.mouse_support) self.stdout.print("{s}", .{mibu.utils.disable_mouse_tracking}) catch {};

    self.raw_term.disableRawMode() catch {};
    self.stdout.flush() catch {};
}

pub fn constraints(self: *Self) ui.Constraints {
    return .{
        .max_w = self.runestone.term_w,
        .max_h = self.runestone.term_h,
    };
}

pub fn engrave(self: *Self, root: anytype) !void {
    try root.inscribe(&self.runestone, 0, 0);
    try self.runestone.engrave(self.stdout);
}

pub fn handleInput(self: *Self, event: mibu.events.Event, root: anytype) !bool {
    var e = event;
    if (e == .mouse) {
        const y_offset = self.runestone.y_offset;
        const res = @subWithOverflow(e.mouse.y, y_offset);
        e.mouse.y = if (res[1] == 1) 0 else @intCast(res[0]);
    }

    return try root.handleInput(e);
}
