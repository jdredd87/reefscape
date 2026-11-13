' DEVELOPER BUILD ONLY - build.ps1 -Store leaves this file out.
' A store screensaver must not have Main() (Roku would treat it as an app, not a screensaver).

' Lets you launch it like a normal app from the home screen. Press * on the remote for settings.
' Launch options (via the Roku's network control): hour=21.5 starts at that time of day,
' demo=1 runs a 4-minute day, settings=1 opens the settings panel, setscene=1 the screensaver's Custom settings screen.
sub Main(args as dynamic)
    ' setscene=1: open the screensaver's own settings screen (Custom settings), to test it without the remote
    if args <> invalid and args.setscene <> invalid then
        RunScreenSaverSettings()
        return
    end if
    showOcean(args)
end sub
