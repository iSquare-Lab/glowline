# Glowline

Glowline is a calm light puzzle made with Godot 4. Light flows from the sun in the middle of the board along the
pipes. Turn the tiles so every lantern glows and no pipe ends in the dark.

- **40 levels**, from 4×4 to 9×9, each made by the same seeded generator every time, plus a **daily puzzle** (8×8)
  that changes at midnight.
- **Stars**: finish within par (the fewest turns for the generator's answer) for three stars.
- **Lock** a tile you are sure of so it cannot turn by mistake; **undo** and **restart** any time.
- **Touch, mouse and keyboard**: tap or click turns a tile; hold or right-click locks it; arrows move, Space turns,
  Q turns back, L locks, U undoes, R restarts, Esc leaves.
- Progress and the sound setting stay in your browser (Godot's `user://`, IndexedDB on the web). No accounts, no
  tracking, no network calls.
- Sounds are made in code; there are no image or audio files besides the icon.

## How it runs on the web

`web/` is the Godot web export, committed: Strux serves it as a static site (`strux.json`, `"output": "web"`).
It is the **single-threaded** export (`variant/thread_support=false`), so it needs **no SharedArrayBuffer and no
cross-origin isolation headers** (COOP/COEP) and runs on any static host. `project/shell.html` is the page around
the game, with its own loading screen.

| File | Size |
|---|---|
| `index.wasm` (Godot 4.7.2 engine) | 39.5 MB |
| `index.pck` (the game) | 40 KB |
| everything else | 0.3 MB |

## Build it

You need [Godot 4.7.2](https://godotengine.org/download) and its export templates (Editor → Manage Export
Templates, or unpack `web_nothreads_release.zip` from the official `.tpz` into the templates folder).

```sh
GODOT=/path/to/godot ./export.sh
```

`export.sh` imports the project, runs the logic tests (`project/tests/test_puzzle.gd`) and exports to `web/`.
To play locally, serve `web/` with any static server (for example `npx serve web`); opening `index.html` as a file
does not work.

## Code map

- `project/scripts/puzzle.gd`: the board: generation (a random tree of pipes from the sun, then random turns), turning,
  which tiles the light reaches, when it is solved, and par.
- `project/scripts/board.gd`: drawing, animation and input for the board.
- `project/scripts/main.gd`: menu, levels, game screen, results, how to play, saved progress.
- `project/scripts/stars.gd`, `project/scripts/sfx.gd`: drawn stars and the sounds made in code.
- `project/tests/test_puzzle.gd`: the puzzle logic, run headless.

## Licence

MIT, see [LICENSE](LICENSE). Godot Engine is MIT licensed (© Godot Engine contributors, Juan Linietsky,
Ariel Manzur).
