const std = @import("std");
const runes = @import("runes");

const mibu = runes.mibu;
const Forge = runes.Forge;
const Stack = runes.inscriptions.Stack;

const Task = struct {
    text: []const u8,

    pub fn inscribe(self: *Task, index: usize, selected: bool, artisan: *runes.inscriptions.Artisan) !usize {
        const prefix = if (selected) "> " else "  ";
        const style: runes.Rune.Style = .{
            .fg = if (selected) .{ .xterm = .red } else .default,
            .attr = .{ .bold = selected },
        };

        return try artisan.inscribe("{s} {d}. {s}", .{ prefix, index + 1, self.text }, style);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin_file = std.fs.File.stdout();

    var stdout_buffer: [1024]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout_writter = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writter.interface;

    var tasks: [5]Task = .{
        .{ .text = "Forge Zig project sigil" },
        .{ .text = "Summon the Moon Rune" },
        .{ .text = "Inscribe the Scroll of Shadows" },
        .{ .text = "Enchante the Dragon Glyph" },
        .{ .text = "Summon the Phoenix Rune" },
    };

    var list = runes.inscriptions.List(Task).init(&tasks, 10);
    list.title = "Simple List";

    var list2 = runes.inscriptions.List(Task).init(&tasks, 10);
    list2.title = "Simple List 2";
    list2.border = true;

    var hstack = Stack.init(.{
        .children = &.{
            .init(&list, .{}),
            .init(&list2, .{}),
        },
        .direction = .horizontal,
        .layout = .factor,
    });

    var forge = try Forge.init(allocator, stdin_file, stdout, .{});
    defer forge.deinit(); // stdout is flushed on defer

    while (true) {
        // -- engrave (draw) into stdout
        try forge.engrave(&hstack);
        try stdout.flush(); // don't forget to flush

        // -- events
        const event = try mibu.events.nextWithTimeout(stdin_file, 100); // 100ms
        if (event.matchesChar('q', .{}) or event.matchesChar('c', .{ .ctrl = true })) break;
        _ = try forge.handleInput(event, &hstack);
    }
}
