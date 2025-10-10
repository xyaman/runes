pub const chars = @import("char_utils.zig");

/// FrameLimiter provides a simple way to skip engraving (drawing) if not
/// enough time has passed since the last frame.
/// Useful for keeping a fixed refresh rate for terminal UIs—good enough for
/// spinners, timers, clocks, etc.
///
/// **Note**: It doesn't guarantee exact interval, but avoids unnecessary redraws
/// and keeps code simple.
///
/// Usage:
/// ```zig
/// var limiter = runes.utils.FrameLimiter.init(.{ .max_fps = 30 });
/// while (true) {
///     if (limiter.shouldRender()) try forge.engrave(&root);
///
///     // handle input/events
/// }
/// ```
pub const FrameLimiter = struct {
    last_frame_ms: i64 = 0,
    min_interval_ms: i64,

    pub const Options = struct {
        ms: ?i64 = null, // Minimum milliseconds between frames
        max_fps: ?u32 = null, // Maximum frames per second
    };

    /// Initialize with Options: specify either ms or max_fps.
    pub fn init(options: Options) FrameLimiter {
        var min_interval_ms: i64 = 16; // default ~60 FPS
        if (options.ms) |ms| {
            min_interval_ms = ms;
        } else if (options.max_fps) |max_fps| {
            min_interval_ms = if (max_fps == 0) 16 else @divFloor(1000, max_fps);
        }
        return FrameLimiter{
            .last_frame_ms = 0,
            .min_interval_ms = min_interval_ms,
        };
    }

    /// Returns true if enough time has passed since the last frame.
    /// Otherwise returns false, so you can skip the redraw.
    /// "Good enough" for most spinner, timer, or animated widgets.
    pub fn shouldRender(self: *FrameLimiter) bool {
        const now = @import("std").time.milliTimestamp();
        if (now - self.last_frame_ms >= self.min_interval_ms) {
            self.last_frame_ms = now;
            return true;
        }
        return false;
    }
};
