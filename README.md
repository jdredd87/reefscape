# Reefscape

An animated coral reef screensaver. It comes in three flavours that share the same artwork and behaviour:

| Flavour | What it is | Built with | Where |
|---|---|---|---|
| **Roku** | Screensaver in the Roku Streaming Store | BrightScript / SceneGraph | this folder |
| **Windows (VCL)** | Windows screensaver, a single `Reefscape.scr` | Delphi 13, VCL, drawn with OpenGL | [`delphi/`](delphi/README.md) |
| **FMX** | The same reef as a FireMonkey app | Delphi 13, FMX, drawn with Skia | [`delphi/fmx/`](delphi/README.md#the-fmx-app) |

The two Delphi flavours fill ultrawide and multiple monitors with one continuous reef:

![One reef across four monitors](delphi/docs/wide-reef.jpg)

The rest of this page describes the reef and the Roku flavour; the Delphi flavours have their own page,
[`delphi/README.md`](delphi/README.md).

## The reef

An animated "2.5D" coral reef: depth layers with parallax camera sway, depth haze, sun rays,
moving caustics on the sand, bubbles, swaying kelp and ~30 animated creatures: reef fish, schools,
lionfish, sharks, sea turtles, mantas, jellyfish, octopus, a dolphin pod, a distant whale, seahorses,
crabs, sea stars, a moray eel in the rock cave, a snapping shrimp that pops out of the sponge tubes, a colony of garden eels that duck into the sand, and a clownfish pair living in the anemone. Reef fish scatter when a shark swims through, and on the nights after a full moon the corals spawn under the moonlight. Now and then Scuba Steve, a scuba
diver, passes far away (at night with a dive torch, in December in a Santa hat), Captain Greg's tiny yellow submarine crosses even farther back, a rare pufferfish puffs up when a shark comes near and drifts away on the current, an anglerfish with a glowing lure prowls at night, and a baited fishing hook comes down; a fish always steals the worm and gets away.

**Day/night:** follows the Roku's clock. Warm light at sunrise/sunset; at night the reef darkens,
plankton and jellyfish glow, reef fish shelter and octopus/sharks/lionfish come out.

**Settings:** Settings > Theme > Screensavers > Reefscape > *Custom settings* (or press * when
running it as an app): lighting mode (clock / always day / sunset / night / fast cycle), an optional
clock (time, date or both; it hops corners every few minutes to avoid burn-in), how many animals swim at once
(a few / some / lots: a third, two thirds or all of the reef-fish slots; a few by default) and a checklist of which animals
(plus Scuba Steve the diver and the fishing hook) appear. Saved in the registry section `CoralReef` (the old name, kept so saved settings survive the rename).

## Build & install
```powershell
.\build.ps1 -RokuIP 192.168.50.162 -Password <dev password>   # zip + sideload (prints compile errors if any)
.\tools\roku.ps1 log      # launch it and print the Roku debug console
.\tools\roku.ps1 shot     # save a screenshot of the TV to out\screenshot.jpg
                          # (reads the dev password from tools\roku-password.txt, which is not in git)
```
Run these from **PowerShell** (Git Bash's `tar` can't create the zip).

Launch options for testing (`.\tools\roku.ps1 log -Launch "..."`): `hour=21.5` (start at a time of day),
`demo=1` (whole day in 4 minutes), `settings=1` (open the settings panel),
`off=shark%2Ceel` (save that list of disabled animals; `off=none` turns all back on),
`clock=both` (show the clock this run), `count=few|some|lots` (save the animal count setting), `fish=1` (fishing event in 2 s), `diver=1` (send the diver now), `show=puffer|sub|angler` (send that rare visitor now), `season=xmas` (Santa hat), `shrimp=1` (shrimp pops out now),
`shark=1` (a close-up shark pass in 2 s, to see fish scatter), `spawn=1` (treat tonight as a full-moon coral spawning night; use with `hour=22`),
`quality=0|1|2` (force minimal / reduced / full quality; the probe then measures every 5 s and only reports),
`hide=surfaceGroup%2Crays` (hide nodes by id, to find which layer causes a drawing problem). `setscene=1` opens the screensaver's Custom settings screen. Combine with `&`.

Quality tiers: the scene starts at full quality, or lower on Roku Express / Streaming Stick, older models and
720p Roku TVs, and steps down a tier if its frame-rate probe reads under 26 twice in a row. The probe reads about 29 on a healthy
Roku (it is capped near 30) and prints `fps NN, quality N` to the debug console.
When running as an app the remote also works: Left/Right shift the time by an hour, OK resets,
Play toggles the 4-minute day, * opens settings.

## Artwork
All art is generated: `node tools\make-art.js` draws every asset as SVG and renders it to
`images\ocean\*.png` with headless Chrome (creatures also get a mirrored `_l` copy).
Render just some assets with `node tools\make-art.js shark_body shark_tail`.
`node tools\preview.js parts` builds a contact sheet in `out\preview-parts.png`.
Every render is then recompressed losslessly by `tools\optimize-png.py` (same pixels, smaller files; needs
`python -m pip install pyoxipng pillow`; set `NOOPT=1` to skip it while iterating). Roku rejects packages over 4 MB,
so check the size of the signed `.pkg` before uploading. The icons (`images\icon_*.jpg`) are JPEGs for the same reason.
`node tools\make-splash.js` builds the loading screen (`images\splash_fhd.jpg`, `images\splash_hd.jpg`) from the first store screenshot.

## Code map
| File | What it does |
|---|---|
| `source/main.brs` | `RunScreenSaver()` entry point |
| `components/OceanScene.xml` | Layer stack (back to front) |
| `components/OceanScene.brs` | Camera sway, light, caustics, decor, bubbles, particles, creature slots and spawning |
| `components/Creature.*` | One creature: builds its parts, animates tails/flippers/wings, swims across, reports `done` |
| `components/Specs.brs` | Creature definitions (part offsets, joints, size, speed) |
| `components/Util.brs` | Shared helpers (looping animations, depth tint) |
| `components/Settings.brs` | Settings storage + the lighting modes and animal list |
| `components/SettingsPanel.*` | The settings UI (used by both the screensaver settings and the app) |
| `components/SettingsScene.*` | Scene for `RunScreenSaverSettings` |

**Adding a creature:** add its art to `make-art.js` (facing right, include it in `MIRROR`),
add a spec in `Specs.brs`, then add its kind name to the `farKinds`/`midKinds`/`nearKinds` (and `...Night`) lists in `OceanScene.brs`
and to `animalList()` in `Settings.brs` so it gets a checkbox.

## Roku gotchas found along the way
- Negative `scale` does not mirror correctly. Use the pre-flipped `_l` images instead.
- `pos` and `or`/`oR` are reserved (case-insensitive). Comparing `invalid = true` crashes, so check `<> invalid`.
- Posters with `width`/`height` get a resized copy in texture memory. Use `scale` to stretch instead.
- Keep images ≤ 2048 px wide.
- Network keypresses (ECP `/keypress`) are blocked on this Roku, but `/launch/dev?params` works, hence the launch options.
- On Roku OS 16 a sideloaded **developer** build (it has `title=` and `Main()`) hangs on the splash when opened from
  Settings > Theme > Screensavers > Reefscape > Custom settings: Roku starts it as an app and never calls `RunScreenSaverSettings`.
  The store build (`.uild.ps1 -Store`) opens it normally. To test that screen with the developer build, launch it with `setscene=1`.

- Right after Reefscape is installed from the store, some Rokus show a home-screen tile for it until the next restart.
  A store screensaver may not have `Main()` (Roku rule 4.5), so the tile can't start anything; the manifest's splash screen
  tells the viewer to turn it on in Settings > Theme > Screensavers instead of showing a blank loading screen.

## Publishing (Roku Streaming Store)

- `.\build.ps1 -Store` makes `out\reefscape-store.zip`: screensaver only. The manifest has no `title=` line and
  `source\dev.brs` (the app-mode `Main()` and test launch options) is left out; a store screensaver must not look like an app.
- `signing\` holds the signing key details (`SIGNING-KEY.txt`) and the signed package. Every update must be
  signed with the same key, so back the folder up and never publish it.
- `store\` holds the listing: `LISTING.md` (texts and dashboard choices), the 540x405 poster, six 1920x1080
  screenshots, and the privacy policy and terms pages, which must be hosted at a public address.

## Testing on other Rokus
Tested 2026-11-12 (Roku OS 16.0.4), probe readings at full / reduced / minimal quality:
Ultra 4850X 29 (stays full); Ultra 4660X (2016) 24 / 26 / 28 (steps to reduced);
TCL Roku TV 7120X 22-24 (steps to reduced); TCL Roku TV 8101X (720p) 24 / 27 / 31 (starts at reduced).
720p Rokus decode large images at 2/3 size via `setImg` (Util.brs) and `components/ImageSizes.brs`
(regenerate with `node tools/make-art.js sizes` after adding images): about 15 MB of textures instead of 34 MB.
Half-size images are drawn with explicit width/height, not scale: some TVs leave gaps with scaled posters.
On 720p Rokus a poster without width/height is drawn 1.5x too big (image pixels are treated as 720p pixels),
so every image goes through `setImg`, which gives it its size there, and XML posters with an image have width/height.
Every sideload leaves the previous install's textures in memory until the Roku restarts, so restart a test
Roku after many installs before judging texture memory (`.\tools\roku.ps1 mem`).
To install on another Roku: `.\build.ps1 -RokuIP <ip> -Password <pw>`; the tools take `-RokuIP` too.
## Windows flavours (Delphi)
The `delphi\` folder holds two Delphi 13 projects that share one copy of the reef code, ported from the
BrightScript in `components\`:

- **VCL screensaver** (`delphi\Reefscape.dproj`, or `delphi\build.ps1`): builds `delphi\bin\Reefscape.scr`, a single
  file drawn with OpenGL. Right-click it and choose Install.
- **FMX app** (`delphi\fmx\ReefscapeFMX.dproj`, or `delphi\fmx\build.ps1`): the same reef drawn with Skia. It takes
  the same command line as the screensaver (`/s`, `/w`, `/c`, `/p`) and needs `sk4d.dll` beside it.

Both widen the reef to fit ultrawide and multiple monitors, offer four choices for more than one screen (one wide
reef, the same reef on each, a different reef on each, main screen only) and show the date and time on the main
screen only. See [`delphi/README.md`](delphi/README.md).

A change to the reef's behaviour should go into the Roku and the Delphi code: `Specs.brs` ↔ `ReefSpecs.pas`,
`Creature.brs` ↔ `ReefCreature.pas`, `OceanScene.brs` ↔ `ReefScene.pas` (the VCL and FMX flavours share those
Pascal units, so that is one change for both). The Roku package is not affected by this folder (the Roku build
only packs `manifest`, `source`, `components` and `images`).
