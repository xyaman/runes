# Runes

> Tested with Zig version `0.15.1` (release)

## Overview

**Runes** is a lightweight UI framework written in Zig, designed for composable, responsive terminal or graphical interfaces.
It provides a structured approach to building interactive applications through a hierarchy of layout and widget abstractions.

Documentation (auto-generated): [https://xyaman.github.io/runes/](https://xyaman.github.io/runes/)

---

## Core Concepts

| Concept | Description |
|----------|-------------|
| **Rune** | A single drawable cell (the smallest visual unit). |
| **Runestone** | A canvas or buffer containing a grid of `Rune`s, representing the current screen. |
| **Forge** | The top-level session or application controller that manages the render and input loop. |

---

## Widgets: Inscriptions


**Inscriptions** are UI components that can measure, render, and handle input.
Each inscription can be drawn onto a `Runestone` at a specific position.

### Base API

```zig
pub fn measure(self: *Self) common.Size { ... }

pub fn inscribe(self: *Self, stone: *Runestone, x: usize, y: usize) !void { ... }

pub fn handleInput(self: *Self, event: mibu.events.Event) !bool { ... }
```

### Layout System

Runes provides flexible layout behavior through Stacks, similar to CSS Flexbox.
Each layout can arrange widgets using one of two modes:


| Mode | Description |
|----------|-------------|
| **Factor** | Positions and sizes elements proportionally based on available space (responsive).
| **Sequential** | Places each element immediately after the previous one, allowing a fixed gap between them.


### Built-in Inscriptions (Widgets)

Stack
- Arranges widgets vertically or horizontally.
- Supports `.factor` and `.sequential` layout modes.
- Responsive resizing.
- Mouse input supported.

List
- Displays a general-purpose scrollable list of items.
- Mouse input supported.


## Dependencies

- [mibu](https://github.com/xyaman/mibu)

## License

- MIT
