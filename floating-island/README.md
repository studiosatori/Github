# Floating Island

A cozy idle game: a small low-poly island floats on your macOS desktop, and grass slowly grows on top of it.

- Frameless, transparent window: only the island shows, floating over your other apps and on every Space.
- The island bobs gently and turns slowly.
- A new grass tuft sprouts every 6 seconds and grows in over 30 seconds. The ground turns from dirt to meadow as the grass spreads (220 tufts, about 22 minutes to fill).
- Progress is saved. Grass keeps growing while the app is closed (up to 8 hours).
- Drag the island to move it. Clicks on the transparent area pass through to the apps behind.
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
| `IslandWindow.swift` | Transparent floating window, and a view you drag to move it |
| `IslandBuilder.swift` | Procedural low-poly island and grass tuft shapes |
| `GrassField.swift` | The idle growth mechanic |
| `IslandScene.swift` | Camera, lights, bob and spin |
| `AppDelegate.swift` | Game loop, click-through, menus, save/load |

Tuning knobs: `GrassField.sproutInterval`, `growDuration`, `maxTufts`, and `IslandScene.seed` (changes the island's shape).
