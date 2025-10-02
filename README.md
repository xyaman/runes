# runes

> Tested with zig version `0.15.1` (release)

# API

- Cell: Rune
- Screen/Canvas: Runestone (buffer of Runes)
- Session/App: Forge

- Widgets: Inscriptions
    - `pub fn measure(self: *Self) common.Size {...}`
    - `pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void { ... }`
    - `pub fn handleInput(self: *Self, event: mibu.events.Event) void { ... }`

# dependencies

- [mibu](https://github.com/xyaman/mibu)
