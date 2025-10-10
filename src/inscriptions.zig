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
//! - `z_index: usize` – z-index, bigger number means more layer
//!
//! ## UI-related
//! - `focused: bool` – Whether the widget currently has focus. Widget behaviour
//!    may change (ex. Input: show/hide cursor when focused).
//! - `hidden: bool` – If `true`, the `inscribe` function must be skipped and
//!   `self.w` and `self.h` should be set to 0.
//! - `border: bool` – Whether the widget currently has border.
//! - `margin: ui.Margin` – Margin
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
//! you should use the `Artisan` helper. Check out `List(T)` and `T` for
//! examples of how to implement and use `Artisan`.
//! ================================================================ NEW
//! ## Geometry (Rect)
//! Widgets must contain a single `rect: ui.Rect` field. This field serves a dual purpose:
//!
//! - __At initialization:__ `rect.w` and `rect.h` can be set to define the widget's default
//!   __intrinsic size__. A value of `0` often means "size to content". `rect.x` and
//!   `rect.y` are typically initialized to `0`.
//!
//! - __After `inscribe()` is called:__ The entire `rect` field holds the __final, allocated geometry__
//!   as determined by a parent container. A widget should update its own `rect` with the
//!   one passed into `inscribe()` and should not modify it further.
//!
//! - `rect: ui.Rect` – The widget's intrinsic and final geometry.
//!
//! - `z_index: usize` – z-index, bigger number means more layer.

pub const ui = @import("inscriptions/ui.zig");

// helpers
pub const Artisan = @import("inscriptions/Artisan.zig");

// widgets
pub const Text = @import("inscriptions/Text.zig");
pub const Input = @import("inscriptions/Input.zig");
pub const List = @import("inscriptions/list.zig").List;
pub const Stack = @import("inscriptions/Stack.zig");
pub const Dropdown = @import("inscriptions/Dropdown.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}

test "inscriptions are well-formed" {
    const std = @import("std");

    var failed = false;

    const Inscriptions = .{
        // helper: Artisan,
        // generic: list,
        Text,
        Input,
        Stack,
        Dropdown,
    };

    inline for (Inscriptions) |Inscription| {
        const name = @typeName(Inscription);

        inline for (.{ "x", "y", "w", "h", "z_index", "focused", "hidden", "border", "margin" }) |field| {
            if (!@hasField(Inscription, field)) {
                std.debug.print("Error: {s} missing field '{s}'\n", .{ name, field });
                failed = true;
            }
        }

        inline for (.{ "inscribe", "handleInput" }) |decl| {
            if (!@hasDecl(Inscription, decl)) {
                std.debug.print("Error: {s} missing method '{s}'\n", .{ name, decl });
                failed = true;
            }
        }
    }

    if (failed) return error.Missing;
}
