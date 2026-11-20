REEFSCAPE FOR WINDOWS - FMX VERSION (drawn with Skia)
=====================================================

An animated coral reef for your screen: fish, sharks, turtles, jellyfish, a moray eel, garden eels, Scuba
Steve the diver and more, with day and night following your PC's clock.

This is the FireMonkey (FMX) build. It shows the same reef as the VCL screensaver and can be used two ways:
as a Windows screensaver, or as an ordinary program in a window.

This package holds three files. KEEP THEM TOGETHER IN ONE FOLDER:

  ReefscapeFMX.scr   the screensaver
  ReefscapeFMX.exe   the same program as an ordinary app (opens the reef in a window)
  sk4d.dll           the Skia drawing library. The other two will not start without it beside them.

Needs: 64-bit Windows 10 or 11.

Which should I use? If you only want a screensaver and like the idea of a single file, the VCL package
(Reefscape.scr) is simpler. Use this one if you want the reef in a window as well, or prefer Skia drawing.


USE IT AS A SCREENSAVER
-----------------------
1. Put all three files in a folder where they can stay. Windows remembers where the .scr is, so do not
   leave them in Downloads if you tidy that folder. A good place is a folder of your own such as
   C:\ReefscapeFMX. (If you use C:\Windows\System32 instead, copy sk4d.dll there too.)
2. Right-click ReefscapeFMX.scr and choose "Install".
   Windows opens Screen Saver Settings with it selected. It is listed as "Reefscape (FMX)" or
   "ReefscapeFMX".
3. Set "Wait" to the number of minutes of idle time you want, and click OK.

To try it first: right-click ReefscapeFMX.scr and choose "Test". Move the mouse or press a key to close it.

If Windows shows "Windows protected your PC" the first time, that is because the files are not signed by a
paid publisher certificate. Click "More info", then "Run anyway".

If the files came from a download, Windows may also block them: right-click each file, choose Properties,
tick "Unblock" at the bottom of the General tab and click OK. If you unpacked a .zip, it is easier to
unblock the .zip before unpacking it.


USE IT AS A PROGRAM IN A WINDOW
-------------------------------
Double-click ReefscapeFMX.exe. The reef opens in a window you can resize; a wider window shows a longer reef.

  F or F11        full screen on / off
  Double-click    full screen on / off
  S               settings
  Right-click     settings
  Esc             leave full screen, or close the program


SETTINGS
--------
Screensaver: right-click ReefscapeFMX.scr and choose "Configure", or click "Settings..." in Screen Saver
Settings.   Program: press S or right-click the reef.

  Time of day       Follow the clock (default), always day, always sunset, always night, or a fast
                    day/night cycle (a whole day every 20 minutes).
  Clock             Off (default), time, date, or date and time. It moves to another corner every few
                    minutes so it cannot burn into the screen.
  How many animals  A few (default), some, or lots.
  More than one     Used by the screensaver (and by /s):
  screen            One wide reef across all screens (default): the reef stretches over every monitor
                    and the animals swim from one to the next.
                    The same reef on every screen.
                    A different reef on each screen.
                    Main screen only: the other screens go black.
                    With several screens the date and time always show on the main screen only.
  Animals and       Tick or untick each animal and event (25 of them).
  events to show

Click OK to save. These settings are shared with the VCL screensaver if you have both.


THINGS TO LOOK FOR
------------------
  - Fish scatter when a shark swims through.
  - A rare pufferfish puffs up when a shark heads its way, then drifts off on the current.
  - Garden eels duck into the sand when something swims close, and sleep in their burrows at night.
  - At night: glowing plankton and jellyfish, an anglerfish with a glowing lure, and Scuba Steve's torch.
  - On the nights after a full moon the corals spawn.
  - From 1 to 26 December Scuba Steve wears a Santa hat.
  - Now and then a baited fishing hook comes down. A fish always steals the worm.


REMOVE
------
1. If you installed the screensaver: open Screen Saver Settings (press the Windows key, type
   "screen saver", choose "Change screen saver") and pick another screensaver or "(None)". Click OK.
2. Delete the three files.
3. Optional: the settings are in the registry under HKEY_CURRENT_USER\Software\Reefscape. You can delete
   that key with Registry Editor; leaving it does no harm.


IF SOMETHING IS WRONG
---------------------
  "sk4d.dll was not found", or nothing happens at all
      sk4d.dll must be in the same folder as the .scr / .exe you are starting.
  The picture is a little soft on a 4K monitor
      The artwork is drawn for 1920 x 1080 and enlarged on bigger screens.
  The screensaver closes straight away
      Any key or mouse movement ends a screensaver. A mouse on an uneven surface can do it.


COMMAND LINE (optional)
-----------------------
Use ReefscapeFMX.exe for these. (Windows always starts a .scr file full screen, whatever else you type.)

  ReefscapeFMX.exe                          the reef in a window
  ReefscapeFMX.exe /w                       the same
  ReefscapeFMX.exe /s                       full screen over every monitor; a key or the mouse closes it
  ReefscapeFMX.exe /c                       the settings only
  ReefscapeFMX.exe /s screens=each          a different reef on each monitor
  ReefscapeFMX.exe hour=23 diver=1          night, with Scuba Steve on his way
  ReefscapeFMX.exe show=puffer              a pufferfish, then a shark about 16 seconds later

screens=span   one wide reef across all screens (default)
screens=same   the same reef on every screen
screens=each   a different reef on each screen
screens=main   main screen only; the others go black

Other options: hour=0..24  light=auto|day|sunset|night|cycle  clock=off|time|date|both  count=few|some|lots
off=shark,eel  show=puffer|sub|angler  shark=1  spawn=1  season=xmas  diver=1  fish=1  shrimp=1
size=1280x720  full=1  settings=1  quit=10 (close after 10 seconds).  Options last for that run only.


Created by Steven Chesser & Claude.   Source: https://github.com/jdredd87/reefscape
sk4d.dll is the Skia4Delphi library, supplied with Delphi for redistribution.
Questions or problems: admin@chesser.wtf
