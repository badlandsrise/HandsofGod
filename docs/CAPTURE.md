# Marketing capture mode

A developer-only mode for recording trailer and store footage of Hands of God:
direct scene launch into bundled, deterministic start states for Eras 1-3,
repeatable camera presets and moves, clean (UI-free) frames, pause and reset,
and two scripted demonstrations that play through the real hand, people and
jobs. It records with Godot's Movie Maker. The goodbye (the ending) is kept
apart as **SPOILER** footage.

It is off in normal play. Nothing loads or shows unless the command line
carries `--capture` after the `--` separator. No menu, key or setting reaches
it, and a capture session never writes a save (it cannot overwrite a player's
valley).

- Code: `scripts/capture/` (`capture.gd` is the director). The only hooks are
  one line in `scripts/front/boot.gd` (skip the splash and title) and one
  branch in `scripts/world/world.gd` `_ready()` (attach the director).
- Data: `data/capture/cameras.json` (presets and moves), plus the start states
  `era1_mid.json`, `era2_start.json` and `era3_start.json`. These ship in the
  export through `include_filter` in `export_presets.cfg`.
- Test: `godot --headless --path . -s tests/capture/test_capture.gd`
- Example stills: `tests/shots/cap_*.png`, made with `tests/capture/cap_shots.gd`.

## The start states

| `--era` | File | What is in it |
|---|---|---|
| 1 | `era1_mid.json` | Mid Era 1 (Tribe): day 16, summer, 14 people, six huts, the fire circle, the shrine and the stone circle going up |
| 2 | `era2_start.json` | The start of Era 2 (Village), the bot's save: day 24, summer, 17 people, cottages |
| 3 | `era3_start.json` | The start of Era 3 (Town), the bot's save: day 66, summer, 59 people, the full Era 2 village, the bridge and the fields |

`era1_mid.json` is regenerated with
`godot --headless --path . -s tests/capture/gen_era1_mid.gd`. That command lets
the Era 1 bot play from the storm night (seed 7) until there are at least two
huts, a lit fire and eight or more people, then saves on a green morning. The
Era 2 and Era 3 files are copies of `tests/bot/era2_start.json` and
`era3_start.json`, with one change: the clock is moved from the snowy early
spring the bot saved in to summer (`season` 1, `season_t` 90), so all three
eras open green and the matching views really match. `--season=` picks
another season.

Every launch and every reset loads the same file with the same seed (`--seed`,
default 1). The same command line gives the same footage.

## Launch commands (Windows)

There are two ways to run it, and the flags after `--` are the same in both:

- **Exported build:** `HandsOfGod.exe` (from `build/`). Engine options go
  before `--` and capture options after it.
- **Editor / project folder:** the Godot 4.6.1 editor binary run on the
  project folder. Use the `_console` executable to see the capture log.

The examples below assume:

```bat
set GAME=C:\Games\HandsOfGod\HandsOfGod.exe
set GODOT=C:\Tools\Godot_v4.6.1-stable_win64_console.exe
set PROJECT=C:\dev\hands-of-god
set OUT=C:\capture
```

In PowerShell, use `$env:GAME` and so on, or type the paths in full. Each
command fits on one line, so it can be pasted into either shell.

### Eras (free camera, all controls)

| Scene | Exported build | Editor / project |
|---|---|---|
| Era 1, mid Tribe | `%GAME% -- --capture --era=1` | `%GODOT% --path %PROJECT% -- --capture --era=1` |
| Era 2, Village | `%GAME% -- --capture --era=2` | `%GODOT% --path %PROJECT% -- --capture --era=2` |
| Era 3, Town | `%GAME% -- --capture --era=3` | `%GODOT% --path %PROJECT% -- --capture --era=3` |

### A preset at launch (`--cam=<name>`), clean frames

| Shot | Exported build |
|---|---|
| Valley wide, Era 1 | `%GAME% -- --capture --era=1 --cam=valley_wide --hide-ui` |
| Valley wide, Era 2 | `%GAME% -- --capture --era=2 --cam=valley_wide --hide-ui` |
| Valley wide, Era 3 | `%GAME% -- --capture --era=3 --cam=valley_wide --hide-ui` |
| Village close | `%GAME% -- --capture --era=2 --cam=village_close --hide-ui` |
| Fire / green | `%GAME% -- --capture --era=1 --cam=fire_green --hide-ui` |
| River | `%GAME% -- --capture --era=3 --cam=river --hide-ui` |
| Workplace | `%GAME% -- --capture --era=3 --cam=workplace --hide-ui` |
| Hero low angle | `%GAME% -- --capture --era=1 --cam=hero_low --hide-ui` |
| Dolly in over the village (20 s) | `%GAME% -- --capture --era=3 --cam=dolly_village --hide-ui` |
| Orbit the fire (30 s) | `%GAME% -- --capture --era=1 --cam=orbit_fire --hide-ui` |
| Crane reveal (25 s) | `%GAME% -- --capture --era=2 --cam=crane_reveal --hide-ui` |

For the editor route, replace `%GAME%` with `%GODOT% --path %PROJECT%`.

### Scripted demonstrations

| Demo | Exported build | Editor / project |
|---|---|---|
| Worker placement, Era 1 | `%GAME% -- --capture --era=1 --demo=worker_placement --hide-ui --hand-visible` | `%GODOT% --path %PROJECT% -- --capture --era=1 --demo=worker_placement --hide-ui --hand-visible` |
| Worker placement, Era 2 | `%GAME% -- --capture --era=2 --demo=worker_placement --hide-ui --hand-visible` | `%GODOT% --path %PROJECT% -- --capture --era=2 --demo=worker_placement --hide-ui --hand-visible` |
| Worker placement, Era 3 | `%GAME% -- --capture --era=3 --demo=worker_placement --hide-ui --hand-visible` | `%GODOT% --path %PROJECT% -- --capture --era=3 --demo=worker_placement --hide-ui --hand-visible` |
| Village life, Era 1 | `%GAME% -- --capture --era=1 --demo=village_life --hide-ui` | `%GODOT% --path %PROJECT% -- --capture --era=1 --demo=village_life --hide-ui` |
| Village life, Era 2 | `%GAME% -- --capture --era=2 --demo=village_life --hide-ui` | `%GODOT% --path %PROJECT% -- --capture --era=2 --demo=village_life --hide-ui` |
| Village life, Era 3 | `%GAME% -- --capture --era=3 --demo=village_life --hide-ui` | `%GODOT% --path %PROJECT% -- --capture --era=3 --demo=village_life --hide-ui` |

A demo starts 1.5 s after the state loads and runs for a fixed 30 s. Use
`--demo-length=S` to change the length. Add `--quit-after` to close the game
when the demo ends, which is how a Movie Maker recording stops.

**worker_placement:** the hand glides to a villager and lifts them
(`Hand.try_lift`). It then sweeps a scoop over the people standing nearby
(`Hand.scoop_lift`), or lifts each one in turn when nobody is close enough.
It carries them over the valley in an eased arc and sets them down on a real
job (`Hand.place_on_site`). The camera then holds while they start work. The
job is chosen from the live village: real work with room for the whole
handful, a good stretch of valley away, never prayer or water-fetching. In Era 1
and Era 2 the hand lifts three people (Grip II). In Era 3 it lifts up to four
(Grip III), as many as the chosen job takes.

**village_life:** a slow camera drift through the village while the people
carry on with whatever the village AI has them doing. The clock is set to late
afternoon so that dusk falls about 55 % of the way through. The village fires
are topped up through the fire Site's own `add_fuel`, so they are burning when
night comes. In Era 3, the street lamps light themselves at dusk.

### SPOILER footage: the goodbye

> **SPOILER: the ending of the game.** Keep this footage out of anything public
> unless the goodbye is meant to be shown.

`--spoiler=goodbye` reuses the existing `--goodbye` dev entry: a generated
Era 4 launch site, about seventy people with a six-generation family tree, and
the Book. The capture controls work on top of it. The goodbye plays itself
(autopilot, steady camera). Add `--manual` to play the player's part yourself.

| Shot | Exported build |
|---|---|
| The whole goodbye, from the evening | `%GAME% -- --capture --spoiler=goodbye` |
| The rocket on the pad (countdown) | `%GAME% -- --capture --spoiler=goodbye --cam=rocket --hide-ui` |
| Liftoff | `%GAME% -- --capture --spoiler=goodbye --cam=liftoff --hide-ui` |
| The lineage in the stars | `%GAME% -- --capture --spoiler=goodbye --cam=lineage` |
| Low under the rocket (pinned camera) | `%GAME% -- --capture --spoiler=goodbye --cam=rocket_low --hide-ui` |

For the editor route, replace `%GAME%` with `%GODOT% --path %PROJECT%`.

Spoiler presets (keys 1-9 in spoiler mode): `evening`, `crew`, `rocket`,
`liftoff`, `wave`, `light`, `lineage` (each jumps to that beat of the
goodbye, keeping its own cinematic camera), `rocket_low` and `pad_wide`
(cameras pinned in the launch site's frame). Jumping to an earlier beat
rebuilds the goodbye first. `R` starts it again from the evening.

## Recording with Movie Maker

Godot's Movie Maker writes every frame at a fixed frame rate, whatever the
machine's speed. It puts engine options before `--`:

- `--write-movie <file>`: the extension picks the format. `.avi` is MJPEG
  video with PCM audio in one file. `.png` writes a numbered PNG sequence plus
  a `.wav` (lossless, best for editing). `.ogv` is Ogg Theora.
- `--fixed-fps 30`: the frame rate of the movie. Movie Maker forces a fixed
  rate anyway, and this option sets it.
- `--resolution 1920x1080`: the frame size. Use `3840x2160` for 4K.
- Recording runs slower than real time on a slow machine, but the footage
  plays at full speed.

Capture mode is deterministic under Movie Maker. Its clock replaces the
game's wall-clock `Clock.real_delta` with the fixed frame step, which is what
the hand, the camera rig, the HUD and the goodbye run on. Demos, camera moves
and the seeds run on that same step. Two recordings of the same command give
the same frames, and the log prints a `state hash` at the end of each demo to
confirm it.

**Worker placement, 1080p30 AVI (exported build):**

```bat
%GAME% --write-movie %OUT%\worker_placement_era1.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=1 --demo=worker_placement --hide-ui --hand-visible --quit-after
```

**Village life, PNG sequence (exported build):**

```bat
%GAME% --write-movie %OUT%\village_life_era3\frame.png --fixed-fps 30 --resolution 1920x1080 -- --capture --era=3 --demo=village_life --hide-ui --quit-after
```

**The same from the project folder (editor binary):**

```bat
%GODOT% --path %PROJECT% --write-movie %OUT%\worker_placement_era2.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=2 --demo=worker_placement --hide-ui --hand-visible --quit-after
%GODOT% --path %PROJECT% --write-movie %OUT%\village_life_era1.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=1 --demo=village_life --hide-ui --quit-after
```

**A held preset or a camera move.** `--quit-after=S` stops after S seconds of
footage:

```bat
%GAME% --write-movie %OUT%\valley_wide_era1.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=1 --cam=valley_wide --hide-ui --quit-after=8
%GAME% --write-movie %OUT%\valley_wide_era2.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=2 --cam=valley_wide --hide-ui --quit-after=8
%GAME% --write-movie %OUT%\valley_wide_era3.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=3 --cam=valley_wide --hide-ui --quit-after=8
%GAME% --write-movie %OUT%\crane_reveal_era3.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --era=3 --cam=crane_reveal --hide-ui --quit-after=26
```

**SPOILER, liftoff:**

```bat
%GAME% --write-movie %OUT%\SPOILER_liftoff.avi --fixed-fps 30 --resolution 1920x1080 -- --capture --spoiler=goodbye --cam=liftoff --hide-ui --quit-after=24
```

The demo's `--quit-after` (after `--`) is not the same as Godot's own
`--quit-after <frames>` (before `--`). Either one ends a recording.
Use absolute output paths: in an exported build, a relative path is resolved
next to the executable.

### Exported release builds and `--write-movie`

The Godot 4.6.1 Windows release export template (`windows_release_x86_64.exe`)
was checked here. It contains the `--write-movie` and `--fixed-fps` command-line
handling and the MJPEG/PNG movie writers, so `HandsOfGod.exe --write-movie ...`
is expected to record. That could not be run on Windows from this machine. If
an exported build ignores `--write-movie` (no file appears), use the
project-folder route: the official Godot 4.6.1 editor binary with
`--path <project>`, as in the examples above. It always supports Movie Maker,
gives the same footage, and needs the project folder (the repository), not the
`.exe`.

Clips recorded headlessly here (in a virtual X display with the software
Vulkan renderer, 960x540, 30 fps) confirmed the pipeline end to end for both
demos. They are not kept in the repository.

## Controls (capture mode)

Hold **F1** to see these keys on screen. The card shows only while the key is
held, so it never ends up in a recording by accident.

| Key | What it does |
|---|---|
| 1-9 | Camera presets and moves from `cameras.json` (see the next section). In spoiler mode, the spoiler presets |
| 0 | Free camera: the game's own rig (WASD/arrows to pan, Q to rotate, wheel to zoom, middle-drag), starting from the current framing |
| Shift+1 / 2 / 3 | Load Era 1 / 2 / 3, keeping the current preset: the same shot before and after |
| H | Hide / show all UI: the HUD, notices, tooltips, cards, the cursor, site bars and labels, and the ghost hand |
| G | Keep the hand in shot while the UI is hidden (its cursor dot, rings and drop ghosts stay hidden) |
| P (or Space) | Pause / resume. The valley, the demo and camera moves all freeze, and the free camera can still move |
| R | Reset to the start state: the same valley, seed, clock and camera, and the running demo from its first frame |
| [ and ] | Time of day back / forward by an hour (1/24 of the day) |
| N | Next season |
| K | Run the worker-placement demo now |
| V | Run the village-life demo now |
| F1 (hold) | The controls card |
| Esc | The game menu (Quit to desktop) |

In capture mode, the game's own bindings for 1-3 (speed), R (rotate), F1
(Book), F5 and F9 (quicksave and quickload) are lifted for that session only.
Naming and era cards are accepted automatically so footage never stalls on a
modal.

### Launch options (after `--`)

| Option | Meaning |
|---|---|
| `--capture` | Turn on capture mode. Skips the splash, title and intro |
| `--era=1\|2\|3` | Which bundled start state to open (default 1) |
| `--seed=N` | RNG seed (default 1) |
| `--cam=<name>` | Start on a preset or move (or a spoiler preset) |
| `--hide-ui` | Start with clean frames |
| `--hand-visible` | With `--hide-ui`, keep the hand in shot |
| `--demo=worker_placement\|village_life` | Run a scripted demonstration |
| `--demo-length=S` | Demo length in seconds (default 30) |
| `--quit-after` / `--quit-after=S` | Quit when the demo ends, or after S seconds |
| `--paused` | Start paused |
| `--tod=0..1` | Time of day as a fraction of the whole day and night (0 dawn, about 0.35 midday, about 0.7 dusk, 0.85 night) |
| `--season=spring\|summer\|autumn\|winter` | Season |
| `--threats` | Let threats happen (wolves, fires, storms). Off by default for calm footage |
| `--spoiler=goodbye` | **SPOILER:** the goodbye with capture controls |
| `--manual` | Spoiler only: play the player's part yourself |

## Camera presets (`data/capture/cameras.json`)

A preset frames a ground point. It sets `focus` [x, z] in metres (with an
optional `focus_h` above the terrain), `dist`, `yaw_deg` (0 puts the camera
south of the focus looking north at the cliffs) and `pitch_deg`, plus `fov`,
`tilt_shift` (the game's diorama blur) and `far`. Heights come from the bare
terrain, not the buildings, so a preset with no `eras` override frames exactly
the same shot in every era. Those are the matching valley views.

| Key | Name | Shot | Matching across eras |
|---|---|---|---|
| 1 | `valley_wide` | The whole valley from above the river, the cliffs and mountains behind | yes |
| 2 | `village_close` | The village at the game's own 3/4 angle | yes |
| 3 | `fire_green` | The fire and the green | yes |
| 4 | `river` | Low over the river, looking back at the village | yes |
| 5 | `workplace` | Where the work is: the flint and berries by the cave (Era 1), the drying rack and store (Era 2), the smelter and smithy (Era 3) | per era |
| 6 | `hero_low` | A low hero angle across the village to the cliffs | yes |
| 7 | `dolly_village` | Move: a slow dolly in over the village, 20 s | yes |
| 8 | `orbit_fire` | Move: orbit 120 degrees round the fire, 30 s | yes |
| 9 | `crane_reveal` | Move: crane up from the hero angle to the whole valley, 25 s | yes |

A move eases in and out between two specs (or preset names) over a fixed
`duration`, so it can be repeated exactly. To add a shot, add an entry with a
free `key`. To tune one, fly there with the free camera (key 0), then copy the
numbers.
