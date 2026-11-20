REEFSCAPE FOR WINDOWS - VCL SCREENSAVER
=======================================

An animated coral reef for your screen: fish, sharks, turtles, jellyfish, a moray eel, garden eels, Scuba
Steve the diver and more, with day and night following your PC's clock.

This package holds one file:

  Reefscape.scr     the screensaver (everything is inside it; no other files are needed)

Needs: 64-bit Windows 10 or 11 and a graphics card or chip with OpenGL 2.0 or later (any PC from the last
15 years has this).


INSTALL
-------
1. Put Reefscape.scr somewhere it can stay. Windows remembers where the file is, so do not leave it in
   Downloads if you tidy that folder. A good place is a folder of your own such as C:\Reefscape, or
   C:\Windows\System32 if you want it listed for every user of the PC (Windows asks for administrator
   permission to copy a file there).
2. Right-click Reefscape.scr and choose "Install".
   Windows opens Screen Saver Settings with Reefscape already selected.
3. Set "Wait" to the number of minutes of idle time you want, and click OK.

If Windows shows "Windows protected your PC" the first time you open the file, that is because the file is
not signed by a paid publisher certificate. Click "More info", then "Run anyway".

If the file came from a download, Windows may also block it: right-click the file, choose Properties, tick
"Unblock" at the bottom of the General tab and click OK.


TRY IT WITHOUT INSTALLING
-------------------------
Right-click Reefscape.scr and choose "Test" (or just double-click it). The reef fills your screens.
Move the mouse or press any key to close it.


SETTINGS
--------
Right-click Reefscape.scr and choose "Configure", or click "Settings..." in Screen Saver Settings.

  Time of day       Follow the clock (default), always day, always sunset, always night, or a fast
                    day/night cycle (a whole day every 20 minutes).
  Clock             Off (default), time, date, or date and time. It moves to another corner every few
                    minutes so it cannot burn into the screen.
  How many animals  A few (default), some, or lots.
  More than one     One wide reef across all screens (default): the reef stretches over every monitor
  screen            and the animals swim from one to the next.
                    The same reef on every screen.
                    A different reef on each screen.
                    Main screen only: the other screens go black.
                    With several screens the date and time always show on the main screen only.
  Animals and       Tick or untick each animal and event (25 of them).
  events to show

Click OK to save. The settings are kept for your Windows user account.


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
1. Open Screen Saver Settings (press the Windows key, type "screen saver", choose "Change screen saver")
   and pick another screensaver or "(None)". Click OK.
2. Delete Reefscape.scr.
3. Optional: the settings are in the registry under HKEY_CURRENT_USER\Software\Reefscape. You can delete
   that key with Registry Editor; leaving it does no harm.


IF SOMETHING IS WRONG
---------------------
  Nothing happens, or an error about OpenGL
      Update your graphics driver. Over Remote Desktop the reef runs, but slowly.
  It is jerky with several monitors
      Choose "Main screen only" or "The same reef on every screen" in the settings.
  The picture is a little soft on a 4K monitor
      The artwork is drawn for 1920 x 1080 and enlarged on bigger screens.
  It closes straight away
      Any key or mouse movement ends a screensaver. A mouse on an uneven surface can do it.


FOR TESTING (optional)
----------------------
Windows always starts a .scr file full screen, so to use these, copy Reefscape.scr to Reefscape.exe first.

  Reefscape.exe /w                         run in an ordinary window (Esc closes it)
  Reefscape.exe /s                         run full screen
  Reefscape.exe /c                         open the settings
  Reefscape.exe /w hour=23 diver=1         night, with Scuba Steve on his way
  Reefscape.exe /w show=puffer             a pufferfish, then a shark about 16 seconds later
  Reefscape.exe /s screens=each            full screen, a different reef on each monitor

Options: hour=0..24  light=auto|day|sunset|night|cycle  clock=off|time|date|both  count=few|some|lots
off=shark,eel  screens=span|same|each|main  show=puffer|sub|angler  shark=1  spawn=1  season=xmas  diver=1
fish=1  shrimp=1  size=1280x720  quit=10 (close after 10 seconds).  Options last for that run only.


Created by Steven Chesser & Claude.   Source: https://github.com/jdredd87/reefscape
Questions or problems: admin@chesser.wtf
