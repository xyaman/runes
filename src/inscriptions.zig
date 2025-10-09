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

pub const ui = @import("inscriptions/ui.zig");

// helpers
pub const Artisan = @import("inscriptions/Artisan.zig");

// widgets
pub const Text = @import("inscriptions/Text.zig");
pub const Input = @import("inscriptions/Input.zig");
pub const List = @import("inscriptions/list.zig").List;
pub const Stack = @import("inscriptions/Stack.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}

test "inscriptions are well-formed" {
    const std = @import("std");

    var failed = false;

    const Inscriptions = .{
        // helper: @import("inscriptions/Artisan.zig"),
        @import("inscriptions/Text.zig"),
        @import("inscriptions/Input.zig"),
        // @import("inscriptions/list.zig").List,
        @import("inscriptions/Stack.zig"),
    };

    inline for (Inscriptions) |Inscription| {
        const name = @typeName(Inscription);

        inline for (.{ "x", "y", "w", "h", "focused", "hidden", "border", "margin" }) |field| {
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
