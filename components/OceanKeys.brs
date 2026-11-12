' DEVELOPER BUILD ONLY - build.ps1 -Store leaves this file (and its <script> line in OceanScene.xml) out.
' Roku does not allow screensavers to use onKeyEvent(); this is only for running Reefscape as an app
' (* opens settings, left/right shift the hour, play toggles a fast day).

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    ' settings panel open: Back or * closes it (the panel itself has no key handler)
    if m.settingsPanel.visible then
        if key = "back" or key = "options" then
            onSettingsDone()
            return true
        end if
        return false
    end if
    handled = true
    if key = "options" then
        openSettingsPanel()
        return true
    else if key = "right" or key = "left" then
        ' shift the shown time by an hour (for this session only)
        target = currentHour() + 1
        if key = "left" then target = target - 2
        m.lightMode = "auto"
        m.demo = false
        m.timeOffset = 0
        m.timeOffset = target - currentHour()
    else if key = "OK" then
        loadUserSettings()
    else if key = "fastforward" or key = "play" then
        h = currentHour()
        m.lightMode = "auto"
        m.demo = not m.demo
        m.demoStart = h
        m.demoT0 = m.clock.TotalMilliseconds()
    else
        handled = false
    end if
    if handled then
        updateLight()
        showTime()
    end if
    return handled
end function
