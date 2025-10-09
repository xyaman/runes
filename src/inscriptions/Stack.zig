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
h: usize = 0, // this value is set in `inscribe`
w: usize = 0, // this value is set in `inscribe`
x: usize = 0, // this value is set in `inscribe`
y: usize = 0, // this value is set in `inscribe`
//
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
        measure: *const fn (*anyopaque) ui.Size,
        setGeometry: *const fn (*anyopaque, usize, usize, usize, usize) void,
    };

    pub inline fn measure(self: Child) ui.Size {
        return self.vtable.measure(self.ptr);
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

            pub fn measure(ptr: *anyopaque) ui.Size {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                // Check that all required fields exist
                if (!@hasField(@TypeOf(self.*), "x") or !@hasField(@TypeOf(self.*), "y") or !@hasField(@TypeOf(self.*), "w") or !@hasField(@TypeOf(self.*), "h")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have fields: x, y, w, h");
                }

                return .{
                    .w = @field(self, "w"),
                    .h = @field(self, "h"),
                };
            }

            pub fn setGeometry(ptr: *anyopaque, x: usize, y: usize, w: usize, h: usize) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                // Check that all required fields exist
                if (!@hasField(@TypeOf(self.*), "x") or !@hasField(@TypeOf(self.*), "y") or !@hasField(@TypeOf(self.*), "w") or !@hasField(@TypeOf(self.*), "h")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have fields: x, y, w, h");
                }

                @field(self.*, "x") = x;
                @field(self.*, "y") = y;
                @field(self.*, "w") = w;
                @field(self.*, "h") = h;
            }
        };

        return .{
            .ptr = inscription,
            .vtable = &.{
                .measure = impl.measure,
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
    var curry: usize = y + self.margin.y + @intFromBool(self.border);
    var currx: usize = x + self.margin.x + @intFromBool(self.border);

    if (self.hidden) {
        self.w = 0;
        self.h = 0;
        for (self.children) |child| {
            child.setGeometry(0, 0, 0, 0);
        }

        return;
    }

    // total sum of factors
    var total_factor: usize = 0;
    for (self.children) |child| {
        total_factor += child.factor;
    }

    // stack dimensions are re-calculated on every draw
    self.h = 0;
    self.w = 0;

    // nothing to draw
    if (total_factor == 0) return;

    switch (self.direction) {
        .vertical => {
            const available_h = rs.term_h - y - rs.y_offset - self.margin.y;
            const unit_h = switch (self.layout) {
                .sequential => 1,
                .factor => @divFloor(available_h, total_factor),
            };

            for (self.children) |child| {
                try child.inscribe(rs, currx, curry);
                const size = child.measure();
                switch (self.layout) {
                    .factor => {
                        const sy = curry;
                        curry += unit_h * child.factor;

                        // TODO Current bug: the width is setted in the next render
                        // not in the initial
                        // when using .factor the height is determined by the stack,
                        // so we need to update the child's geometry
                        child.setGeometry(currx, sy, size.w, unit_h * child.factor);
                        self.h += curry;
                    },
                    .sequential => {
                        curry += size.h + self.gap;
                        self.h += size.h + self.gap;
                    },
                }
                self.w = @max(self.w, size.w);
            }

            // remove the trailing gap if we had any children
            if (self.children.len > 0) self.h -= self.gap;
        },
        .horizontal => {
            const available_w = rs.term_w - x;
            const unit_w = switch (self.layout) {
                .sequential => 1,
                .factor => @divFloor(available_w, total_factor),
            };

            for (self.children) |child| {
                try child.inscribe(rs, currx, curry);
                const size = child.measure();

                switch (self.layout) {
                    .factor => {
                        const sx = currx;
                        currx += unit_w * child.factor;

                        // TODO Current bug: the width is setted in the next render
                        // not in the initial
                        // when using .factor the width is determined by the stack,
                        // so we need to update the child's geometry
                        child.setGeometry(sx, curry, unit_w * child.factor, size.h);
                        self.w += currx;
                    },
                    .sequential => {
                        currx += size.w + self.gap;
                        self.w += size.w + self.gap;
                    },
                }

                self.h = @max(self.h, size.h);
            }

            // remove the trailing gap if we had any children
            if (self.children.len > 0) self.w -= self.gap;
        },
    }

    // adjust width
    self.h += 2 * @as(usize, @intFromBool(self.border));
    self.w += 2 * @as(usize, @intFromBool(self.border));

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
