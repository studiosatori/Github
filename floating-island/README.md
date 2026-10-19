# Floating Island

A cozy idle game: a small, blue-tinted, low-poly island of uneven rock floats on your macOS desktop. A small cedar cabin with a deck sits on top, a chubby tabby in overalls lazes about, and grass slowly grows. Pixelated, PS1-style textures.

- Frameless, transparent window: only the island shows, floating over your other apps and on every Space.
- A new grass tuft sprouts every 1.75 seconds and grows in over 30 seconds. The ground turns from dirt to meadow as the grass spreads (800 tufts, about 23 minutes to fill).
- Progress is saved. Grass keeps growing while the app is closed (up to 8 hours).
- Drag the island to move it. Hover over the window and drag the round button in the top-right corner to resize it. Clicks on the transparent area pass through to the apps behind.
- Use the 🏝 menu bar icon or right-click the island to see grass progress, toggle Keep on Top, reset, or quit.

## Run

Requires macOS 13 or later and Xcode (or the Xcode Command Line Tools).

```sh
cd floating-island
swift run
```

You can also open `Package.swift` in Xcode and press Run.

## Code

| File | What it does |
|---|---|
| `IslandWindow.swift` | Transparent floating window, drag-to-move, and the resize button |
| `IslandBuilder.swift` | Procedural low-poly island and grass tuft shapes |
| `GrassField.swift` | The idle growth mechanic |
| `IslandScene.swift` | Puts the scene together: island, temple, cat, camera, lights |
| `Landmarks.swift` | Cabin, deck and chairs, and the ground they block |
| `Cat.swift` | The cat: her look, sitting, blinking and slow strolls |
| `Textures.swift` | Tiny procedural pixel textures |
| `Shapes.swift` | Box, pyramid and post building blocks |
| `AppDelegate.swift` | Game loop, click-through, menus, save/load |

Tuning knobs: `GrassField.sproutInterval`, `growDuration`, `maxTufts`, and `IslandScene.seed` (changes the island's shape).
