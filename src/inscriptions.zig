//! Inscriptions (Widgets)
//!
//! All inscriptions should define the following attributes to be considered __well-formed__.
//! This ensures a standardized API without requiring a shared interface or trait.
//!
//! Convention over configuration.
//!
//! ## Geometry (Rect)
//! These values may be initialized to `0`, but should adapt dynamically when
//! the widget’s layout changes. It is recommended to recalculate them inside
//! `self.inscribe`.
//!
//! - `x: usize` – X position
//! - `y: usize` – Y position
//! - `w: usize` – Width
//! - `h: usize` – Height
//!
//! ## UI-related
//! - `focused: bool` – Whether the widget currently has focus. Behaviour might change
//! - `hidden: bool` – If `true`, the `inscribe` function must be skipped and
//!   `self.w` and `self.h` should be set to 0.
//!
//! ## Interface Methods
//! Every inscription **should** implement the following methods:
//!
//! ```zig
//! pub fn measure(ptr: *anyopaque) ui.Size { ... }
//! pub fn inscribe(ptr: *anyopaque, rs: *Runestone, x: usize, y: usize) !void { ... }
//! pub fn handleInput(ptr: *anyopaque, event: mibu.events.Event) !bool { ... }
//! ```
//!
//! These functions allow inscriptions to be composed and managed uniformly
//! through vtables without depending on compile-time generics.
//!
//! When you need to expose or draw directly to the canvas (`Runestone`),
//! you should use the `Artisan` helper.
//!
//! Check out `List(T)` and `T` for examples of how to implement inscriptions.

pub const Artisan = @import("inscriptions/Artisan.zig");
pub const Text = @import("inscriptions/Text.zig");
pub const Input = @import("inscriptions/Input.zig");

pub const List = @import("inscriptions/list.zig").List;
pub const Stack = @import("inscriptions/Stack.zig");
pub const ui = @import("inscriptions/ui.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
