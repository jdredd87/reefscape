' Shared settings storage (the registry is shared by the app and the screensaver)

function lightModes() as object
    return [
        ["auto", "Follow the clock"]
        ["day", "Always day"]
        ["sunset", "Always sunset"]
        ["night", "Always night"]
        ["cycle", "Fast day/night cycle"]
    ]
end function

function clockModes() as object
    return [
        ["off", "Off"]
        ["time", "Time"]
        ["date", "Date"]
        ["both", "Date and time"]
    ]
end function

' how many swimming animals at once (the fish in the reef's three depth layers)
function countModes() as object
    return [
        ["few", "A few"]
        ["some", "Some"]
        ["lots", "Lots"]
    ]
end function

' key = creature kind used by the scene, label = what the user sees
function animalList() as object
    return [
        ["tang", "Blue tangs"]
        ["ytang", "Yellow tangs"]
        ["angel", "Angelfish"]
        ["clown", "Clownfish"]
        ["school", "Fish schools"]
        ["lionfish", "Lionfish"]
        ["shark", "Reef sharks"]
        ["turtle", "Sea turtles"]
        ["manta", "Manta rays"]
        ["jelly", "Jellyfish"]
        ["octopus", "Octopus"]
        ["dolphin", "Dolphins"]
        ["whale", "Humpback whale"]
        ["seahorse", "Seahorses"]
        ["crab", "Crabs"]
        ["star", "Sea stars"]
        ["eel", "Moray eel"]
        ["shrimp", "Snapping shrimp"]
        ["oyster", "Oyster with a pearl"]
        ["geel", "Garden eels"]
        ["spawn", "Coral spawning (full moon)"]
        ["diver", "Scuba Steve"]
        ["hook", "Fishing hook"]
    ]
end function

function loadSettings() as object
    sec = CreateObject("roRegistrySection", "CoralReef")
    light = "auto"
    if sec.Exists("light") then light = sec.Read("light")
    clock = "off"
    if sec.Exists("clock") then clock = sec.Read("clock")
    count = "lots"
    if sec.Exists("count") then count = sec.Read("count")
    off = {}
    if sec.Exists("off") then
        for each k in sec.Read("off").Split(",")
            if k <> "" then off[k] = true
        end for
    end if
    return { light: light, off: off, clock: clock, count: count }
end function

sub saveSettings(st as object)
    s = ""
    for each k in st.off
        if s <> "" then s = s + ","
        s = s + k
    end for
    sec = CreateObject("roRegistrySection", "CoralReef")
    sec.Write("light", st.light)
    sec.Write("clock", st.clock)
    if st.count <> invalid then sec.Write("count", st.count)
    sec.Write("off", s)
    sec.Flush()
end sub
