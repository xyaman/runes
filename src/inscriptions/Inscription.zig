const std = @import("std");
const mibu = @import("mibu");

const common = @import("common.zig");
const Runestone = @import("../Runestone.zig");

const Self = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    measure: *const fn (*anyopaque) common.Size,
    inscribe: *const fn (*anyopaque, *Runestone, usize, usize) anyerror!void,
    handleInput: *const fn (*anyopaque, mibu.events.Event) void,
};

pub fn measure(self: Self) common.Size {
    return self.vtable.measure(self.ptr);
}

pub fn inscribe(self: Self, rs: *Runestone, x: usize, y: usize) anyerror!void {
    return self.vtable.inscribe(self.ptr, rs, x, y);
}

pub fn handleInput(self: Self, event: mibu.events.Event) void {
    return self.vtable.handleInput(self.ptr, event);
}
