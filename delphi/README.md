# Reefscape for Windows (Delphi 13)

The Windows screensaver version of the Roku reef. It uses the same artwork (`..\images\ocean`) and the
same behaviour: the code is a port of `components\*.brs`, kept close to the original so a change on one
side is easy to carry to the other.

## Build

- **In the IDE:** open `Reefscape.dproj` in Delphi 13 and build (Win64 or Win32). Run (F9) opens the reef
  in a test window.
- **From the command line:** `.\build.ps1` (add `-Win32` for a 32-bit build, `-Run` to open a test window).

The result is `bin\Reefscape.scr`, a single file with all the artwork inside it.

## Install

Right-click `bin\Reefscape.scr` and choose **Install**, or copy it to `C:\Windows\System32` and pick
Reefscape in *Screen Saver Settings*. **Settings...** there opens the options: time of day, clock,
how many animals, which animals, and what to do with more than one screen.

## Files

| File | What it is |
|---|---|
| `ReefEngine.pas` | Small scene graph (groups, images, rectangles) and animation engine, drawn with OpenGL. It mirrors the way Roku SceneGraph works. |
| `ReefSpecs.pas` | The animals: parts, joints, sizes and speeds (`Specs.brs`). |
| `ReefCreature.pas` | One animal: building it, swimming, fleeing, the pufferfish (`Creature.brs`). |
| `ReefScene.pas` | The reef: layers, light, residents, visitors, day and night (`OceanScene.brs`). |
| `ReefSettings.pas` | Settings in the registry (`HKCU\Software\Reefscape`) and the lists shown in the dialog. |
| `ConfigForm.pas/.dfm` | The settings dialog. |
| `SaverMain.pas` | The screensaver shell: `/s`, `/p`, `/c`, the window and the frame loop. |
| `ReefRes.rc` | Icon, manifest, version and one line per image. Written by `make-rc.ps1`. |

## When the artwork changes

Images are compiled into the program from `..\images\ocean`. After `node tools/make-art.js`:

- changed images: just rebuild;
- images added or removed: run `.\make-rc.ps1`, then rebuild.

## Testing

Windows always starts a `.scr` file full screen, whatever else is on the command line, so test from a
copy named `.exe` (`build.ps1 -Run` makes `bin\ReefTest.exe`):

```
bin\ReefTest.exe /w hour=22 show=puffer
```

`/w` = ordinary window (Esc closes it), `/s` = full screen, `/c` = settings.
Options: `hour=` `light=` `clock=` `count=` `off=a,b` `screens=span|same|each|main` `show=puffer|sub|angler`
`shark=1` `spawn=1` `season=xmas` `diver=1` `fish=1` `shrimp=1` `seed=` `size=1280x720`
`ff=20` (skip ahead 20 seconds) `quit=5` (close after 5 seconds) `shot=file.png` `log=file.txt`.

## Differences from the Roku version

- The reef has no fixed width. It is as wide as the screen's shape asks for: an ultrawide monitor, or several
  monitors side by side, show one longer reef and the animals swim its whole length. The backgrounds and the
  fixed residents repeat in sections (`Tile`, `SecGroup`, `Layout` in `ReefScene.pas`); every other section is
  mirrored and laid out differently so the joins don't show.
- Several screens: one wide reef across all of them (default), the same reef on each (drawn once and copied),
  a different reef on each, or the main screen only. The screensaver is a single window over the whole desktop.
- A screen less wide than 16:9 crops a little rather than stretching.
- No quality tiers: a PC draws everything.
- Motion is computed every frame instead of from key frames, so loops are a little smoother.
