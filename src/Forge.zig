const std = @import("std");
const mibu = @import("mibu");
const Runestone = @import("Runestone.zig");

const Self = @This();

allocator: std.mem.Allocator,
runestone: Runestone,
stdin_file: std.fs.File,
stdout: *std.Io.Writer,
raw_term: mibu.term.RawTerm,
options: Options = .{},

pub const Options = struct {
    alternate_screen: bool = false,
    hide_cursor: bool = true,
    fullscreen: bool = false,
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
    };

    if (options.alternate_screen) try mibu.term.enterAlternateScreen(forge.stdout);
    if (options.hide_cursor) try mibu.cursor.hide(forge.stdout);
    return forge;
}

pub fn deinit(self: *Self) void {
    self.runestone.deinit();

    if (self.options.alternate_screen) mibu.term.exitAlternateScreen(self.stdout) catch {};
    if (self.options.hide_cursor) mibu.cursor.show(self.stdout) catch {};
    self.raw_term.disableRawMode() catch {};
    self.stdout.flush() catch {};
}
