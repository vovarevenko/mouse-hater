# Mouse Hater

Click anywhere on screen with the keyboard — no mouse, no trackpad.

Tap **Command** to summon a labelled grid over the screen, then type a short
sequence of keys to narrow to a point and click it.

## First launch

Open `Mouse Hater.app`, then look for the cursor icon in the menu bar.

Mouse Hater asks for **Accessibility** access on first launch. Enable it in
*System Settings → Privacy & Security → Accessibility* so the app can read the
global keyboard trigger and post clicks.

It also registers itself as **Open at Login** once, so it is available after
restarts. macOS shows its standard login-item notification when this happens.
You can turn it off or back on any time from the status-bar menu.

## How it works

1. **Tap Command** (configurable — see *Trigger* below). A `10 × 30` grid appears
   over the screen that holds the mouse cursor. **Every cell is labelled with its
   own two letters** — a column key (`a … ;`, left → right) and a row key
   (`q … /`, top → bottom):

   ```txt
    ┌────┬────┬────┬─────┬────┐
    │ aq │ sq │ dq │ …kq │ ;q │   ← every cell is labelled
    ├────┼────┼────┼─────┼────┤      with its own column+row
    │ aw │ sw │ dw │ …kw │ ;w │      letters (10 × 30 cells)
    ├────┼────┼────┼─────┼────┤
    │ a… │ s… │ d… │  …  │ ;… │
    ├────┼────┼────┼─────┼────┤
    │ a/ │ s/ │ d/ │ …k/ │ ;/ │
    └────┴────┴────┴─────┴────┘
   ```

2. **Type the cell's two letters: column then row** (e.g. `a` `t`). The column
   key picks 1 of 10 columns; the row key picks 1 of 30 rows. The top keyboard
   row `q–p` maps to the upper third of the screen, the home row `a–;` to the
   middle, the bottom row `z–/` to the lower third.

3. The chosen cell splits into a final **`10 × 3`** grid. **Tap one key** there to
   click the **centre** of that sub-cell.

So the quick path is three keystrokes: `column`, `row`, `refine`.

The labels refer to physical QWERTY key positions, not the character produced by
the active keyboard layout. This keeps the controls layout-independent.

### Nudge — fine-tune before clicking

For tiny targets, **hold** the final `10 × 3` key instead of tapping. After a
brief moment a small crosshair appears at the cell's centre (a quick tap never
flashes it), and your **free hand** steers it — then **release the held key to
click**:

- Holding a key on the **left** half → steer with `I` `J` `K` `L`.
- Holding a key on the **right** half → steer with `E` `S` `D` `F`.
- In each cluster the keys are up / left / down / right; hold a direction to
  glide (it accelerates), or press two at once for a diagonal.

Hold **Shift** as you press the final key to make the release a right-click.

### Space — click without drilling all the way down

- **Before any selection**, `Space` clicks **wherever the cursor already is**.
- **After a selection**, `Space` clicks the **centre of the region narrowed so
  far** — or the **nudge dot**, if you're steering one.

### Left vs. right click

- A letter / `Space` performs a **left click**.
- Hold **Shift** while pressing that key for a **right click**.

### Cancel

- **Esc** — or **tapping Command** again — closes the overlay without clicking.
  Keys that aren't valid for the current step are ignored.

## Trigger

Choose in the status-bar menu:

- **Single Command tap** (default) — press and release Command on its own,
  quickly, with nothing else pressed in between. Normal shortcuts like `⌘C` are
  ignored because another key was involved.
- **Double Command tap** — two quick taps in a row. Use this if the single tap
  fires too eagerly for your typing style.

The menu also has a **Keyboard guide…** item — an in-app cheat sheet of the keys.

## Build & run

Requires macOS 13+ and a Swift 6 toolchain (Xcode 16+).

```sh
./build.sh            # release build -> build/Mouse Hater.app
open "build/Mouse Hater.app"
```

For development, run `swift test` to verify the trigger state machine and grid
geometry independently from AppKit.

Before a release, run:

```sh
swift test
swift build -c release
./build.sh release
```

`build.sh` compiles with SwiftPM, assembles the `.app` bundle, and code-signs it
(ad-hoc by default — see *Accessibility permission* for a stable identity). It
also validates `Resources/Info.plist` and verifies the resulting code signature.
The app runs as a background agent (no Dock icon); look for the
`cursorarrow.click.2` icon in the menu bar.

You can also open `Package.swift` in Xcode and run from there.

## Accessibility permission

Mouse Hater needs **Accessibility** access to read the global keyboard (the
trigger) and to synthesise clicks. The menu shows the current status, and the
menu's *Accessibility* item reopens the right System Settings pane.

> **Keeping the permission across rebuilds.** macOS tracks the grant by the app's
> code signature, so the default ad-hoc build asks for access again after each
> rebuild. To make it stick, sign with a stable identity: export
> `SIGN_IDENTITY=<hash-or-name>` (from `security find-identity -p codesigning`),
> or drop that line into an untracked `.signing.local` next to `build.sh`. macOS
> then keys the grant to that identity rather than the per-build `cdhash`.

## Known limitations (v1)

- The overlay covers **only the screen under the cursor**. To target another
  display, move the mouse there first, then trigger.
- Three keystrokes land within roughly a `15 × 11` pt cell (on a ~1512 × 982 pt
  display; it scales with screen size) — precise enough for most targets.

## License

Released under the MIT License — see [LICENSE](LICENSE).

Copyright © 2026 Vova Revenko
