' Entry point Roku calls when the screensaver kicks in
' (or when you click "Preview" in Settings > Theme > Screensavers).
sub RunScreenSaver()
    showOcean({})
end sub

' Settings > Theme > Screensavers > Reefscape > "Custom settings"
sub RunScreenSaverSettings()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("SettingsScene")
    screen.Show()
    scene.ObserveField("done", port)
    while true
        msg = Wait(0, port)
        if type(msg) = "roSGNodeEvent" and msg.GetField() = "done" then
            screen.Close()
        else if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then
            return
        end if
    end while
end sub

sub showOcean(args as object)
    ' count=few|some|lots: save the animal count setting before the scene reads it
    if args <> invalid and args.count <> invalid then
        sec = CreateObject("roRegistrySection", "CoralReef")
        sec.Write("count", args.count)
        sec.Flush()
    end if
    ' quit=1: exit right away, without loading anything (lets test scripts leave the TV on the home screen)
    if args <> invalid and args.quit <> invalid then return
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("OceanScene")
    screen.Show()
    if args <> invalid then
        if args.hour <> invalid then scene.startHour = args.hour
        if args.demo <> invalid then scene.demo = true
        if args.settings <> invalid then scene.openSettings = true
        if args.off <> invalid then scene.setOff = args.off
        if args.clock <> invalid then scene.clockTest = args.clock
        if args.fish <> invalid then scene.fishTest = true
        if args.diver <> invalid then scene.diverTest = true
        if args.season <> invalid then scene.seasonTest = args.season
        if args.show <> invalid then scene.showTest = args.show
        if args.shrimp <> invalid then scene.shrimpTest = true
        if args.quality <> invalid then scene.quality = args.quality
        if args.spawn <> invalid then scene.spawnTest = true
        if args.shark <> invalid then scene.sharkTest = true
        if args.hide <> invalid then scene.hideTest = args.hide
    end if

    startMemoryMonitor(port)

    ' Roku closes the screensaver itself when the user presses a key.
    while true
        msg = Wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then return
        if type(msg) = "roAppMemoryNotificationEvent" or type(msg) = "roAppMemoryMonitorEvent" then scene.lowMemory = true
    end while
end sub

' Roku's memory monitor: if the device runs low on memory, the scene thins out its animals.
sub startMemoryMonitor(port as object)
    mon = CreateObject("roAppMemoryMonitor")
    if mon = invalid then return
    ' each call is guarded separately: not every Roku OS version has all of them
    try
        mon.SetMessagePort(port)
    catch e1
        print "memory monitor: no message port ("; e1.message; ")"
    end try
    try
        mon.EnableMemoryWarningEvent(true)
    catch e2
        print "memory monitor: no memory warning event ("; e2.message; ")"
    end try
    try
        mon.EnableLowGeneralMemoryEvent(true)
    catch e3
        print "memory monitor: no low memory event ("; e3.message; ")"
    end try
    try
        print "memory limit "; mon.GetChannelMemoryLimit(); ", "; mon.GetMemoryLimitPercent(); "% used, available "; mon.GetChannelAvailableMemory()
    catch e4
        print "memory monitor: no memory figures ("; e4.message; ")"
    end try
end sub
