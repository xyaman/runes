const std = @import("std");
const runes = @import("runes");

const mibu = runes.mibu;
const Forge = runes.Forge;
const Dropdown = runes.inscriptions.Dropdown;
const Text = runes.inscriptions.Text;
const Stack = runes.inscriptions.Stack;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // -------------------------------
    // setup stdin/stdout (Zig 0.15.1 style)
    // -------------------------------
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    // -------------------------------
    // dropdown data
    // -------------------------------
    var colors: [4][]const u8 = .{
        "Red",
        "Green",
        "Blue",
        "Yellow",
    };

    var dropdown = Dropdown.init(&colors, .{});
    dropdown.placeholder = "Select a color";

    var help_text = Text.init("  enter: open/close ・ ↑/k: up ・ ↓/j: down ・ q/ctrl+c: quit", .{ .style = .{ .fg = .{ .xterm = .grey_50 } } });

    // stack layout
    var root = Stack.init(.{
        .children = &.{
            .init(&dropdown, .{}),
            .init(&help_text, .{}),
        },
        .gap = 1,
        .margin = .{ .x = 2, .y = 1 },
    });

    // -------------------------------
    // forge setup
    // -------------------------------
    var forge = try Forge.init(allocator, stdin_file, stdout, .{});
    defer forge.deinit();

    // -------------------------------
    // main loop
    // -------------------------------
    while (true) {
        // draw everything
        try forge.engrave(&root);
        try stdout.flush();

        // event loop
        const event = try mibu.events.nextWithTimeout(stdin_file, 100);

        if (event.matchesChar('q', .{}) or event.matchesChar('c', .{ .ctrl = true })) break;

        _ = try forge.handleInput(event, &root);
    }
}
