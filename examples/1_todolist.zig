const std = @import("std");
const runes = @import("runes");

const mibu = runes.mibu;
const Forge = runes.Forge;
const List = runes.inscriptions.List;
const Text = runes.inscriptions.Text;
const Stack = runes.inscriptions.Stack;
const Input = runes.inscriptions.Input;

const Todo = struct {
    text: [256]u8 = undefined,
    len: usize = 0,

    completed: bool = false,

    pub fn init(text: []const u8) Todo {
        var self = Todo{};
        self.len = text.len;
        @memcpy(self.text[0..self.len], text);
        return self;
    }

    pub fn toggle(self: *Todo) void {
        self.completed = !self.completed;
    }

    pub fn inscribe(self: *Todo, index: usize, selected: bool, artisan: *runes.inscriptions.Artisan) !usize {
        const prefix = if (self.completed) "(x)" else "( )";
        const style: runes.Rune.Style = .{
            .fg = if (selected) .{ .xterm = .red } else .default,
            .attr = .{ .bold = selected },
        };

        return try artisan.inscribe("{s} {d}. {s}", .{ prefix, index + 1, self.text[0..self.len] }, style);
    }
};

const TodoList = struct {
    allocator: std.mem.Allocator,
    todos: std.ArrayListUnmanaged(Todo) = .{},

    list: List(Todo),
    input: Input,
    root: Stack,

    // geometry (needed by Stack)
    x: usize = 0,
    y: usize = 0,
    h: usize = 0,
    w: usize = 0,

    input_selected: bool = false,

    // slice has to live long enough, otherwise we might have vtable dangle pointers
    children_buf: [2]Stack.Child = undefined,

    pub fn init(self: *TodoList, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.todos = try std.ArrayListUnmanaged(Todo).initCapacity(allocator, 10);

        // initialize the list view
        self.list = List(Todo).init(self.todos.items, 10);
        self.input = Input.init(self.allocator, false);
        self.input.placeholder = "Press i to insert";

        // initialize children buffer (no heap)
        self.children_buf[0] = .init(&self.input, .{});
        self.children_buf[1] = .init(&self.list, .{});

        // create root stack with static slice from the buffer
        self.root = Stack.init(.{
            .children = self.children_buf[0..self.children_buf.len],
        });
    }

    pub fn deinit(self: *TodoList) void {
        self.todos.deinit(self.allocator);
        self.input.deinit();
    }

    pub fn insert(self: *TodoList, text: []const u8) !void {
        try self.todos.append(self.allocator, Todo.init(text));
        self.list.items = self.todos.items;
    }

    pub fn inscribe(self: *TodoList, stone: *runes.Runestone, sx: usize, sy: usize) !void {
        // update the list view before drawing
        self.list.items = self.todos.items;
        try self.root.inscribe(stone, sx, sy);
        runes.utils.copyGeometry(self, self.root);
    }

    pub fn handleInput(self: *TodoList, event: mibu.events.Event) !bool {
        // input mode
        if (self.input_selected) {
            if (event == .key) {
                switch (event.key.code) {
                    .enter => {
                        self.input_selected = false;
                        self.input.focused = false;
                        try self.insert(self.input.buffer.items);
                        self.input.clearRetainingCapacity();
                        self.input.placeholder = "Press i to insert";
                        return true;
                    },
                    .esc => {
                        self.input_selected = false;
                        self.input.focused = false;
                        self.input.clearRetainingCapacity();
                        self.input.placeholder = "Press i to insert";
                        return true;
                    },
                    else => {},
                }
            }
            return self.input.handleInput(event);
        }

        // navigation - list mode
        if (event.matchesChar('i', .{})) {
            self.input_selected = true;
            self.input.focused = true;
            self.input.placeholder = "";
            return true;
        }

        // list (2nd priority)
        if (event == .key and (event.key.code == .enter or event.matchesChar(' ', .{}))) {
            self.todos.items[self.list.selected].toggle();
            return true;
        }

        return self.list.handleInput(event);
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

    const initial_tasks: [5][]const u8 = .{
        "Forge Zig project sigil",
        "Summon the Moon Rune",
        "Inscribe the Scroll of Shadows",
        "Enchante the Dragon Glyph",
        "Summon the Phoenix Rune",
    };

    var todolist: TodoList = undefined;
    try todolist.init(allocator);
    defer todolist.deinit();

    for (initial_tasks) |t| {
        try todolist.insert(t);
    }

    var help_text = Text.init("  i: add todo ・ enter/space: toggle todo・↑/k: up ・↓/j: down", .{ .fg = .{ .xterm = .grey_50 } }, false);
    var root = Stack.init(.{
        .children = &.{
            .init(&todolist, .{}),
            .init(&help_text, .{}),
        },
        .gap = 1,
        .margin = .{ .x = 1, .y = 1 },
    });

    var forge = try Forge.init(allocator, stdin_file, stdout, .{});
    defer forge.deinit(); // stdout is flushed on defer

    while (true) {
        // -- engrave (draw) into stdout
        try forge.engrave(&root);
        try stdout.flush(); // don't forget to flush

        // -- events
        const event = try mibu.events.nextWithTimeout(stdin_file, 100); // 100ms
        if (event.matchesChar('c', .{ .ctrl = true })) break;
        _ = try forge.handleInput(event, &root);
    }
}
