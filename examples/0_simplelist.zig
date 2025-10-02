const std = @import("std");
const runes = @import("runes");

const mibu = runes.mibu;
const Forge = runes.Forge;

const Task = struct {
    label: []const u8,
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
        .{ .label = "Forge Zig project sigil" },
        .{ .label = "Summon the Moon Rune" },
        .{ .label = "Inscribe the Scroll of Shadows" },
        .{ .label = "Enchante the Dragon Glyph" },
        .{ .label = "Summon the Phoenix Rune" },
    };

    var list = runes.inscriptions.List(Task).init(&tasks, 10);
    list.title = "Simple List";

    var help_text = runes.inscriptions.Text.init("  ↑/k up ・↓/j down", .{ .fg = .{ .xterm = .grey_50 } }, false);
    var root = runes.inscriptions.Stack.init(.{
        .children = &.{
            .init(&list, .{}),
            .init(&help_text, .{}),
        },
        .gap = 1,
    });

    var forge = try Forge.init(allocator, stdin_file, stdout, .{});
    defer forge.deinit(); // stdout is flushed on defer

    while (true) {
        // -- engrave (draw) into stdout
        try forge.engrave(&root);
        try stdout.flush(); // don't forget to flush

        // -- events
        const event = try mibu.events.nextWithTimeout(stdin_file, 100); // 100ms
        if (event.matchesChar('q', .{}) or event.matchesChar('c', .{ .ctrl = true })) break;
        _ = try forge.handleInput(event, &root);
    }
}
