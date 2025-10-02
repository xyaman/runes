const std = @import("std");
const runes = @import("runes");

const mibu = runes.mibu;
const Forge = runes.Forge;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin_file = std.fs.File.stdout();

    var stdout_buffer: [1024]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout_writter = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writter.interface;

    var tasks: [5][]const u8 = .{
        "Forge Zig project sigil",
        "Summon the Moon Rune",
        "Inscribe the Scroll of Shadows",
        "Enchante the Dragon Glyph",
        "Summon the Phoenix Rune",
    };

    var forge = try Forge.init(allocator, stdin_file, stdout, .{});
    defer forge.deinit(); // stdout is flushed on defer

    var rs = &forge.runestone;
    var list = runes.inscriptions.List.init(&tasks, 10);
    var w = list.inscription();

    while (true) {
        // -- inscriptions (widgets) draw
        try rs.addText(1, 1, "Simple List", .{});
        try w.inscribe(rs, 1, 2);

        // -- engrave (draw) into stdout
        try rs.engrave(stdout);
        try stdout.flush(); // don't forget to flush

        // -- events
        // timeout, so the execution may be stopped for at max 100ms
        const event = try mibu.events.nextWithTimeout(stdin_file, 100);
        if (event.matchesChar('q', .{}) or event.matchesChar('c', .{ .ctrl = true })) break;
        w.handleInput(event);
    }
}
