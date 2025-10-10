//! Stack.zig
//!
//! Provides a flexible stacking layout component for arranging child UI components
//! either vertically or horizontally.
//! Supports sequential and factor-based layout and gaps between children.
//! Each child must implement the `Stack.Child` interface

const std = @import("std");
const assert = std.debug.assert;
const mibu = @import("mibu");

const ui = @import("ui.zig");

const Forge = @import("../Forge.zig");
const Runestone = @import("../Runestone.zig");
const Rune = @import("../Rune.zig");

const Self = @This();

// geometry
rect: ui.Rect = .{ .h = 0, .w = 0, .x = 0, .y = 0 },
z_index: usize = 0,

// common ui
hidden: bool = false,
focused: bool = false,
border: bool,
margin: ui.Margin,

children: []const Child,
direction: Direction,
layout: Layout,
gap: usize,

/// Represents a child UI component inside the stack.
pub const Child = struct {
    // interface
    ptr: *anyopaque,
    vtable: *const VTable,

    // ui-related
    factor: usize,

    pub const Options = struct {
        factor: usize = 1,
    };

    pub const VTable = struct {
        inscribe: *const fn (*anyopaque, *Runestone, usize, usize) anyerror!void,
        handleInput: *const fn (*anyopaque, mibu.events.Event) anyerror!bool,
        rect: *const fn (*anyopaque) ui.Rect,
        setGeometry: *const fn (*anyopaque, usize, usize, usize, usize) void,
    };

    pub inline fn rect(self: Child) ui.Rect {
        return self.vtable.rect(self.ptr);
    }

    pub inline fn inscribe(self: Child, rs: *Runestone, x: usize, y: usize) anyerror!void {
        return self.vtable.inscribe(self.ptr, rs, x, y);
    }

    pub inline fn handleInput(self: Child, event: mibu.events.Event) !bool {
        return try self.vtable.handleInput(self.ptr, event);
    }

    pub inline fn setGeometry(self: Child, x: usize, y: usize, w: usize, h: usize) void {
        return self.vtable.setGeometry(self.ptr, x, y, w, h);
    }

    pub fn init(inscription: anytype, options: Options) Child {
        const Ptr = @TypeOf(inscription);
        const PtrInfo = @typeInfo(Ptr);

        assert(PtrInfo == .pointer); // Must be a pointer
        assert(PtrInfo.pointer.size == .one); // Must be a single-item pointer
        assert(@typeInfo(PtrInfo.pointer.child) == .@"struct"); // Must point to a struct

        const impl = struct {
            pub fn inscribe(ptr: *anyopaque, rs: *Runestone, x: usize, y: usize) !void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return self.inscribe(rs, x, y);
            }

            pub fn handleInput(ptr: *anyopaque, event: mibu.events.Event) !bool {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return try self.handleInput(event);
            }

            pub fn rect(ptr: *anyopaque) ui.Rect {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                // Check that all required fields exist
                // if (!@hasField(@TypeOf(self.*), "x") or !@hasField(@TypeOf(self.*), "y") or !@hasField(@TypeOf(self.*), "w") or !@hasField(@TypeOf(self.*), "h")) {
                //     @compileError(@typeName(@TypeOf(self.*)) ++ " must have fields: x, y, w, h");
                // }
                //
                if (!@hasField(@TypeOf(self.*), "rect")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have field: rect");
                }

                return @field(self, "rect");
            }

            pub fn setGeometry(ptr: *anyopaque, x: usize, y: usize, w: usize, h: usize) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                // Check that all required fields exist
                if (!@hasField(@TypeOf(self.*), "rect")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have field: rect");
                }

                @field(self.*, "rect") = ui.Rect{
                    .x = x,
                    .y = y,
                    .w = w,
                    .h = h,
                };
            }
        };

        return .{
            .ptr = inscription,
            .vtable = &.{
                .rect = impl.rect,
                .inscribe = impl.inscribe,
                .handleInput = impl.handleInput,
                .setGeometry = impl.setGeometry,
            },
            .factor = options.factor,
        };
    }
};

pub const Direction = enum {
    horizontal,
    vertical,
};

pub const Layout = enum {
    sequential,
    factor,
};

pub const InitOptions = struct {
    border: bool = false,
    margin: ui.Margin = .{},
    children: []const Child,
    direction: Direction = .vertical,
    layout: Layout = .sequential,
    gap: usize = 1,
};

/// Initialize a new Stack with options
pub fn init(options: InitOptions) Self {
    return Self{
        .border = options.border,
        .margin = options.margin,
        .children = options.children,
        .direction = options.direction,
        .layout = options.layout,
        .gap = options.gap,
    };
}

/// Draw the stack and its children on the Runestone
pub fn inscribe(self: *Self, rs: *Runestone, x: usize, y: usize) !void {
    if (self.hidden) {
        self.rect.w = 0;
        self.rect.h = 0;
        for (self.children) |child| child.setGeometry(0, 0, 0, 0);
        return;
    }

    var curr_x: usize = x + self.margin.x + @intFromBool(self.border);
    var curr_y: usize = y + self.margin.y + @intFromBool(self.border);

    const available_w = rs.term_w - x - self.margin.x - @intFromBool(self.border);
    const available_h = rs.term_h - y - self.margin.y - @intFromBool(self.border);

    // total factor sum for factor layout

    var total_factor: usize = 0;
    for (self.children) |child| total_factor += child.factor;

    self.rect.w = 0;
    self.rect.h = 0;

    switch (self.direction) {
        .vertical => {
            for (self.children) |child| {
                // stacks start with w = h = 0, causing the first render to be
                // bad
                const child_h = switch (self.layout) {
                    .sequential => child.rect().h,
                    .factor => (available_h * child.factor) / total_factor,
                };

                child.setGeometry(curr_x, curr_y, available_w, child_h);
                try child.inscribe(rs, curr_x, curr_y);
                curr_y += child_h + self.gap;
                self.rect.w = @max(self.rect.w, available_w);
            }
            if (self.children.len > 0) self.rect.h = curr_y - y - self.gap;
        },
        .horizontal => {
            for (self.children) |child| {
                const child_w = switch (self.layout) {
                    .sequential => child.rect().w,
                    .factor => (available_w * child.factor) / total_factor,
                };
                child.setGeometry(curr_x, curr_y, child_w, available_h);
                try child.inscribe(rs, curr_x, curr_y);
                curr_x += child_w + self.gap;
                self.rect.h = @max(self.rect.h, available_h);
            }
            if (self.children.len > 0) self.rect.w = curr_x - x - self.gap;
        },
    }

    // account for borders
    self.rect.w += 2 * @as(usize, @intFromBool(self.border));
    self.rect.h += 2 * @as(usize, @intFromBool(self.border));

    if (self.border) try ui.drawWithBorder(self, rs, null);
}

/// Forward input events to children in order until handled
pub fn handleInput(self: *Self, event: mibu.events.Event) !bool {
    if (self.hidden) return false;

    for (self.children) |child| {
        const handled = try child.handleInput(event);
        if (handled) return true;
    }

    return false;
}
