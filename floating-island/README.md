# Floating Island

A cozy idle game: a small low-poly island of earthy rock floats on your macOS desktop. An old windmill turns slowly on top, a chubby tabby in overalls lazes about, and a leafy meadow with yellow flowers slowly grows in, with vines spilling over the edge. Soft, lo-fi 3D look.

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
| `IslandBuilder.swift` | Procedural low-poly island, leafy grass tufts and flowers |
| `GrassField.swift` | The idle growth mechanic |
| `IslandScene.swift` | Puts the scene together: island, windmill, cat, vines, camera, lights |
| `Landmarks.swift` | The windmill, and the ground it blocks |
| `Vines.swift` | Vines hanging over the edge, growing in with the meadow |
| `Cat.swift` | The cat: her look, sitting, blinking and slow strolls |
| `Textures.swift` | Tiny procedural pixel textures |
| `Shapes.swift` | Box, pyramid and post building blocks |
| `AppDelegate.swift` | Game loop, click-through, menus, save/load |

Tuning knobs: `GrassField.sproutInterval`, `growDuration`, `maxTufts`, and `IslandScene.seed` (changes the island's shape).
