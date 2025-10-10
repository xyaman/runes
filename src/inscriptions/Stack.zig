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
rect: ui.Rect = .{},
computed_rect: ui.Rect = .{},
z_index: usize = 0,

// common ui
hidden: bool = false,
focused: bool = false,
border: bool,
margin: ui.Margin,

children: []const Child,
direction: Direction,
kind: Kind,
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

        layout: *const fn (*anyopaque, ui.Constraints) ui.Size,
        getComputedRect: *const fn (*anyopaque) ui.Rect,
        setGeometry: *const fn (*anyopaque, ui.Rect) void,
    };

    pub inline fn inscribe(self: Child, rs: *Runestone, x: usize, y: usize) anyerror!void {
        return self.vtable.inscribe(self.ptr, rs, x, y);
    }

    pub inline fn handleInput(self: Child, event: mibu.events.Event) !bool {
        return try self.vtable.handleInput(self.ptr, event);
    }

    pub inline fn layout(self: Child, constraints: ui.Constraints) ui.Size {
        return self.vtable.layout(self.ptr, constraints);
    }

    pub inline fn getComputedRect(self: Child) ui.Rect {
        return self.vtable.getComputedRect(self.ptr);
    }

    pub inline fn setGeometry(self: Child, rect: ui.Rect) void {
        return self.vtable.setGeometry(self.ptr, rect);
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

            pub fn layout(ptr: *anyopaque, constraints: ui.Constraints) ui.Size {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                if (!@hasDecl(@TypeOf(self.*), "layout")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have method: pub fn layout(self*, ui.Constraints) ui.Size");
                }

                return self.layout(constraints);
            }

            pub fn getComputedRect(ptr: *anyopaque) ui.Rect {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                if (!@hasField(@TypeOf(self.*), "computed_rect")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have field: computed_rect");
                }

                return @field(self, "computed_rect");
            }

            pub fn setGeometry(ptr: *anyopaque, rect: ui.Rect) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));

                // Check that all required fields exist
                if (!@hasField(@TypeOf(self.*), "computed_rect")) {
                    @compileError(@typeName(@TypeOf(self.*)) ++ " must have field: computed_rect");
                }

                @field(self.*, "computed_rect") = rect;
            }
        };

        return .{
            .ptr = inscription,
            .vtable = &.{
                .getComputedRect = impl.getComputedRect,
                .inscribe = impl.inscribe,
                .layout = impl.layout,
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

pub const Kind = enum {
    sequential,
    factor,
};

pub const InitOptions = struct {
    border: bool = false,
    margin: ui.Margin = .{},
    children: []const Child,
    direction: Direction = .vertical,
    kind: Kind = .sequential,
    gap: usize = 1,
};

/// Initialize a new Stack with options
pub fn init(options: InitOptions) Self {
    return Self{
        .border = options.border,
        .margin = options.margin,
        .children = options.children,
        .direction = options.direction,
        .kind = options.kind,
        .gap = options.gap,
    };
}

/// Modifies the inscription layout, it may also be modified afterwards (before)
/// rendering by the parent, for example when inside an Stack
pub fn layout(self: *Self, constraints: ui.Constraints) ui.Size {
    const border_size: usize = @intCast(@intFromBool(self.border));

    // TODO: take into consideration own stack initial dimensions/rect

    // 1. check visibility
    if (self.hidden) {
        self.computed_rect.w = 0;
        self.computed_rect.h = 0;
        for (self.children) |child| child.setGeometry(.{});
        return .{ .w = 0, .h = 0 };
    }

    // 2. computes available inner space
    const available_w = constraints.max_w - 2 * self.margin.x - 2 * border_size;
    const available_h = constraints.max_h - 2 * self.margin.y - 2 * border_size;

    // 3. measure each child's prefered size
    // todo: use allocator??
    var buffer: [10]ui.Size = undefined;
    var desired_sizes = std.ArrayList(ui.Size).initBuffer(&buffer);

    // var total_sequential_size: usize = 0;

    for (self.children) |child| {
        const child_contraints: ui.Constraints = .{
            .max_w = available_w,
            .max_h = available_h,
        };

        const size = child.layout(child_contraints);
        desired_sizes.appendAssumeCapacity(size);

        // switch (self.direction) {
        //     .vertical => total_sequential_size += size.h,
        //     .horizontal => total_sequential_size += size.w,
        // }
    }

    // reset computed_rect, it wil be computed again
    self.computed_rect = .{};

    // if there are multiple children, add space between them
    // total_sequential_size += @max(0, self.children.len - 1) * self.gap;

    // 4. distributes space (optionally by factor)

    // 5. asigns geometry to each child
    const curr_x: usize = self.margin.x + border_size;
    var curr_y: usize = self.margin.y + border_size;

    for (self.children, 0..) |child, i| {
        const desired_size = desired_sizes.items[i];
        var child_rect: ui.Rect = .{};

        switch (self.direction) {
            .vertical => {
                // sequential: only
                var child_h = desired_size.h;
                child_h = @min(child_h, available_h - curr_y); // todo: check border size

                var child_w = desired_size.w;
                child_w = @min(child_w, available_w);

                child_rect = .{
                    .x = curr_x,
                    .y = curr_y,
                    .w = child_w,
                    .h = child_h,
                };

                curr_y += child_h + self.gap;
                self.computed_rect.h += child_h + self.gap;
                self.computed_rect.w = @max(self.computed_rect.w, child_rect.w);
            },
            .horizontal => {
                @panic("Not implemented.");
                // sequential: only
                // var child_h = desired_size.h;
                // child_h = @min(child_h, available_h);
                //
                // var child_w = desired_size.w;
                // child_w = @min(child_w, available_w - curr_x); // todo: check border size
                //
                // child_rect = .{
                //     .x = curr_x,
                //     .y = curr_y,
                //     .w = child_w,
                //     .h = child_h,
                // };
                //
                // curr_x += child_w + self.gap;
                // self.computed_rect.w += child_w + self.gap;
                // self.computed_rect.h = @max(self.computed_rect.h, child_rect.h);
            },
        }

        child.setGeometry(child_rect);
    }

    // self.h => curr_y
    self.computed_rect.h -= self.gap;
    self.computed_rect.w -= self.gap;

    // 6. computes it's own size
    // Add back margins and borders to our final size
    self.computed_rect.w += 2 * self.margin.x + 2 * border_size;
    self.computed_rect.h += 2 * self.margin.y + 2 * border_size;

    // Clamp our size to the constraints
    self.computed_rect.w = @min(self.computed_rect.w, constraints.max_w);
    self.computed_rect.h = @min(self.computed_rect.h, constraints.max_h);

    // TODO: computed
    return .{
        .w = self.computed_rect.w,
        .h = self.computed_rect.h,
    };
}

/// Draw the stack and its children on the Runestone
pub fn inscribe(self: *Self, rs: *Runestone, x: usize, y: usize) !void {
    if (self.hidden) {
        // self.rect.w = 0;
        // self.rect.h = 0;
        for (self.children) |child| child.setGeometry(.{});
        return;
    }

    for (self.children) |child| {
        // Get the child's rect, which is *relative* to the stack's content area
        const child_rect = child.getComputedRect();

        // Calculate the child's *absolute* screen position
        const abs_x = x + child_rect.x;
        const abs_y = y + child_rect.y;

        try child.inscribe(rs, abs_x, abs_y);
    }

    // Draw our own border, if any
    // if (self.border) try ui.drawWithBorder(self, rs, null);
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
