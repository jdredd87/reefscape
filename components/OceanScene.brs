sub init()
    m.top.backgroundColor = "0x0A4A78FF"
    m.top.backgroundUri = ""
    m.clock = CreateObject("roTimespan")
    m.uid = 0
    m.amp = { far: 25, mid: 60, light: 40, near: 110, front: 160, jelly: 60, glow: 120 }
    m.timeOffset = 0
    m.demo = false
    m.nightShade = m.top.FindNode("nightShade")
    m.warm = m.top.FindNode("warmTint")
    m.rays = m.top.FindNode("rays")
    m.caustics = m.top.FindNode("caustics")
    m.glow = m.top.FindNode("plankton")
    m.timeLabel = m.top.FindNode("timeLabel")
    m.settingsPanel = m.top.FindNode("settingsPanel")
    m.settingsPanel.ObserveField("done", "onSettingsDone")
    m.refocus = m.top.FindNode("refocus")
    m.refocus.ObserveField("fire", "takeFocus")
    loadUserSettings()

    buildLight()
    buildDecor()
    buildEel()
    buildShrimp()
    buildCaustics()
    buildBubbles()
    buildParticles()
    buildPlankton()
    buildClock()
    buildFishing()
    startCamera()
    updateLight()
    buildSlots()
    applyClock()
    m.top.SetFocus(true)

    m.tick = m.top.FindNode("tick")
    m.tick.ObserveField("fire", "onTick")
    m.tick.control = "start"
end sub

' ---------- camera sway (parallax) ----------
sub startCamera()
    anim = m.top.CreateChild("Animation")
    anim.repeat = true
    anim.duration = 46
    anim.easeFunction = "linear"
    layers = [["camFar", m.amp.far], ["camMid", m.amp.mid], ["camLight", m.amp.light], ["camNear", m.amp.near], ["camFront", m.amp.front], ["camJelly", m.amp.jelly], ["camGlow", m.amp.glow]]
    for each L in layers
        interp = anim.CreateChild("Vector2DFieldInterpolator")
        keys = []
        vals = []
        for i = 0 to 32
            t = i / 32
            keys.Push(t)
            vals.Push([L[1] * Sin(t * 6.2831853), L[1] * 0.18 * Sin(t * 12.5663706 + 0.5)])
        end for
        interp.key = keys
        interp.keyValue = vals
        interp.fieldToInterp = L[0] + ".translation"
    end for
    anim.control = "start"
end sub

' ---------- sunlight: rippling surface + light shafts ----------
sub buildLight()
    surf = m.top.FindNode("surfaceGroup")
    surf.translation = [-200, -24]
    for i = 0 to 2
        p = surf.CreateChild("Poster")
        p.uri = img("surface")
        p.scale = [2, 2]
        p.translation = [i * 2048, 0]
    end for
    anim = m.top.CreateChild("Animation")
    anim.repeat = true
    anim.duration = 90
    anim.easeFunction = "linear"
    interp = anim.CreateChild("Vector2DFieldInterpolator")
    interp.key = [0, 1]
    interp.keyValue = [[-200, -24], [-2248, -24]]
    interp.fieldToInterp = "surfaceGroup.translation"
    anim.control = "start"

    rays = m.top.FindNode("rays")
    xs = [120, 480, 820, 1150, 1480, 1760]
    for i = 0 to xs.Count() - 1
        p = rays.CreateChild("Poster")
        p.id = "ray" + i.ToStr()
        p.uri = img("ray")
        p.translation = [xs[i] + rnd(-60, 60), -60]
        ' ray.png is stored at half size, so scale it 2x
        p.scaleRotateCenter = [100, 0]
        p.scale = [rnd(1.2, 2.6), 2.0]
        p.rotation = rnd(0.16, 0.26)
        addLoopFloat(m.top, p.id, "opacity", 0.3, 0.2, rnd(7, 13), rnd(0, 6.28))
    end for
end sub

' ---------- caustics: rippling light network on the sea floor ----------
sub buildCaustics()
    g = m.top.FindNode("caustics")
    layers = [["caustics_a", 0.24, 40, 1], ["caustics_b", 0.17, 57, -1]]
    for i = 0 to 1
        L = layers[i]
        lg = g.CreateChild("Group")
        lg.id = "caus" + i.ToStr()
        lg.opacity = L[1]
        lg.scale = [1, 0.9]
        for k = 0 to 3
            p = lg.CreateChild("Poster")
            p.uri = img(L[0])
            p.translation = [k * 1024, 0]
        end for
        anim = m.top.CreateChild("Animation")
        anim.repeat = true
        anim.duration = L[2]
        anim.easeFunction = "linear"
        interp = anim.CreateChild("Vector2DFieldInterpolator")
        interp.key = [0, 1]
        if L[3] = 1 then
            interp.keyValue = [[-300, 845], [-1324, 845]]
        else
            interp.keyValue = [[-1324, 850], [-300, 850]]
        end if
        interp.fieldToInterp = lg.id + ".translation"
        anim.control = "start"
    end for
end sub

' ---------- corals, kelp and plants ----------
sub buildDecor()
    near = m.top.FindNode("nearDecor")
    items = [
        { uri: "kelp", x: -70, y: 100, rot: 0.035, period: 7.5, px: 85, py: 1000 }
        { uri: "seafan", x: 1640, y: 495, rot: 0.025, period: 9, px: 190, py: 420 }
        { uri: "coral_stag", x: 110, y: 575 }
        { uri: "sponge", x: 435, y: 575 }
        { uri: "seagrass", x: 650, y: 680, rot: 0.07, period: 4.5, px: 110, py: 240 }
        { uri: "anemone", x: 720, y: 690, sc: [0.03, -0.03], period: 5, px: 160, py: 240 }
        { uri: "coral_brain", x: 1010, y: 725 }
        { uri: "coral_stag2", x: 1290, y: 620 }
        { uri: "rock", x: 1420, y: 605 }
        { uri: "seagrass", x: 1940, y: 690, rot: 0.06, period: 5.2, px: 110, py: 240 }
        { uri: "kelp", x: 1840, y: 150, rot: 0.03, period: 8.3, px: 85, py: 1000 }
    ]
    addDecor(near, items, "", 1.0)

    mid = m.top.FindNode("midDecor")
    midItems = [
        { uri: "kelp", x: 360, y: 260, rot: 0.04, period: 9.5, px: 85, py: 1000 }
        { uri: "kelp", x: 1320, y: 220, rot: 0.035, period: 8.7, px: 85, py: 1000 }
        { uri: "seagrass", x: 900, y: 760, rot: 0.06, period: 5.8, px: 110, py: 240 }
    ]
    addDecor(mid, midItems, tintFor(0.5), 0.75)
end sub

sub addDecor(parent as object, items as object, tint as string, scl as float)
    for i = 0 to items.Count() - 1
        it = items[i]
        p = parent.CreateChild("Poster")
        p.id = parent.id + i.ToStr()
        p.uri = img(it.uri)
        p.translation = [it.x, it.y]
        if tint <> "" then p.blendColor = tint
        if it.px <> invalid then p.scaleRotateCenter = [it.px, it.py]
        if scl <> 1.0 then p.scale = [scl, scl]
        if it.rot <> invalid then addLoopFloat(m.top, p.id, "rotation", 0, it.rot, it.period, rnd(0, 6.28))
        if it.sc <> invalid then addLoopVec(m.top, p.id, "scale", [scl, scl], it.sc, it.period, rnd(0, 6.28))
    end for
end sub

' ---------- bubble streams ----------
sub buildBubbles()
    g = m.top.FindNode("bubbles")
    emitters = [[575, 880, 10], [1170, 880, 6], [1700, 900, 5]]
    n = 0
    for each e in emitters
        for i = 0 to e[2] - 1
            b = g.CreateChild("Poster")
            b.id = "bub" + n.ToStr()
            n = n + 1
            sz = rnd(10, 30)
            b.uri = img("bubble")
            b.scale = [sz / 64, sz / 64]
            b.opacity = rnd(0.5, 0.9)
            anim = m.top.CreateChild("Animation")
            anim.repeat = true
            anim.duration = rnd(6, 10)
            anim.delay = i * rnd(0.5, 1.1)
            anim.easeFunction = "linear"
            interp = anim.CreateChild("Vector2DFieldInterpolator")
            keys = []
            vals = []
            ph = rnd(0, 6.28)
            x0 = e[0] + rnd(-15, 15)
            for k = 0 to 12
                t = k / 12
                keys.Push(t)
                vals.Push([x0 + 14 * Sin(t * 9 + ph) + t * 40, e[1] - t * 1020])
            end for
            interp.key = keys
            interp.keyValue = vals
            interp.fieldToInterp = b.id + ".translation"
            b.translation = vals[0]
            anim.control = "start"
        end for
    end for
end sub

' ---------- floating particles ("marine snow") in front of everything ----------
sub buildParticles()
    g = m.top.FindNode("particles")
    for i = 0 to 44
        p = g.CreateChild("Poster")
        p.id = "pt" + i.ToStr()
        p.uri = img("particle")
        sz = rnd(3, 11)
        p.scale = [sz / 32, sz / 32]
        p.opacity = rnd(0.15, 0.5)
        base = [rnd(-150, 2070), rnd(0, 1080)]
        p.translation = base
        addLoopVec(m.top, p.id, "translation", base, [rnd(-60, 60), rnd(30, 90)], rnd(16, 34), rnd(0, 6.28))
    end for
end sub

' ---------- moray eel that peeks out of the rock cave ----------
sub buildEel()
    m.eelWrap = m.top.FindNode("nearDecor").CreateChild("Group")
    outer = m.eelWrap.CreateChild("Group")
    outer.id = "eelOuter"
    outer.scale = [0.8, 0.8]
    head = outer.CreateChild("Group")
    head.id = "eelHead"
    head.scaleRotateCenter = [255, 78]
    jaw = head.CreateChild("Poster")
    jaw.id = "eelJaw"
    jaw.uri = img("eel_jaw")
    jaw.translation = [0, 64]
    jaw.scaleRotateCenter = [90, 8]
    body = head.CreateChild("Poster")
    body.uri = img("eel")

    ' the cave mouth in the rock poster: rock at [1420,605] scaled 1.3, cave centre local [120,172] -> screen [1576,829], 150 x 114
    ' nothing right of x=1612 (deep inside the hole) is drawn, so the eel never paints over the rock
    m.eelWrap.clippingRect = [1150, 690, 462, 280]
    shade = m.eelWrap.CreateChild("Poster")
    shade.uri = img("eel_cave")
    shade.translation = [1491, 764]

    outP = [1392, 765]
    peekP = [1500, 765]
    inP = [1614, 765]
    outer.translation = inP
    anim = m.top.CreateChild("Animation")
    anim.repeat = true
    anim.duration = 24
    anim.easeFunction = "linear"
    ti = anim.CreateChild("Vector2DFieldInterpolator")
    ti.key = [0, 0.12, 0.17, 0.25, 0.33, 0.62, 0.66, 0.72, 1]
    ti.keyValue = [inP, inP, peekP, peekP, outP, outP, [1425, 765], inP, inP]
    ti.fieldToInterp = "eelOuter.translation"
    anim.control = "start"
    m.eelWrap.visible = (m.off["eel"] = invalid)
    addLoopFloat(m.top, "eelJaw", "rotation", 0.13, 0.13, 2.8, 0)
    addLoopFloat(m.top, "eelHead", "rotation", 0, 0.05, 4.5, 1)
end sub

' ---------- snapping shrimp that pops out of the foreground sponge tubes ----------
sub buildShrimp()
    near = m.top.FindNode("nearDecor")
    ' drawn right after the sponge, so plants in front of the sponge stay in front of the shrimp
    idx = near.getChildCount()
    for i = 0 to near.getChildCount() - 1
        c = near.getChild(i)
        if c.subtype() = "Poster" and Instr(1, c.uri, "/sponge.png") > 0 then idx = i + 1
    end for
    m.shrimpClip = CreateObject("roSGNode", "Group")
    near.insertChild(m.shrimpClip, idx)
    g = m.shrimpClip.CreateChild("Group")
    g.id = "shrimpG"
    ' outer group: position + rotation (pivot at the rim); inner group: scale (about its origin)
    m.shrimpIn = g.CreateChild("Group")
    m.shrimpBody = m.shrimpIn.CreateChild("Poster")
    m.shrimpFinger = m.shrimpIn.CreateChild("Poster")
    m.shrimpFinger.id = "shrimpFinger"
    m.shrimpBub = m.shrimpIn.CreateChild("Poster")
    m.shrimpBub.id = "shrimpBub"
    m.shrimpBub.uri = img("bubble")
    m.shrimpBub.scaleRotateCenter = [32, 32]
    m.shrimpBub.opacity = 0

    ' tube openings of the sponge poster (sponge at [435,575]): centre x, rim y, shrimp scale
    m.shrimpTubes = [[504.6, 695.7, 0.6], [591, 612, 0.6], [661.2, 725.6, 0.56], [614.8, 797.4, 0.52]]
    m.shrimpLast = -1
    m.shrimpAnim = m.top.CreateChild("Animation")
    m.shrimpAnim.easeFunction = "linear"
    m.shrimpPos = m.shrimpAnim.CreateChild("Vector2DFieldInterpolator")
    m.shrimpPos.fieldToInterp = "shrimpG.translation"
    m.shrimpRot = m.shrimpAnim.CreateChild("FloatFieldInterpolator")
    m.shrimpRot.fieldToInterp = "shrimpG.rotation"
    m.shrimpSnap = m.shrimpAnim.CreateChild("FloatFieldInterpolator")
    m.shrimpSnap.fieldToInterp = "shrimpFinger.rotation"
    m.shrimpBubS = m.shrimpAnim.CreateChild("Vector2DFieldInterpolator")
    m.shrimpBubS.fieldToInterp = "shrimpBub.scale"
    m.shrimpBubO = m.shrimpAnim.CreateChild("FloatFieldInterpolator")
    m.shrimpBubO.fieldToInterp = "shrimpBub.opacity"
    m.shrimpBubP = m.shrimpAnim.CreateChild("Vector2DFieldInterpolator")
    m.shrimpBubP.fieldToInterp = "shrimpBub.translation"
    placeShrimp(0, false)
    m.shrimpClip.visible = (m.off["shrimp"] = invalid)
    m.shrimpNext = rnd(20, 40) * 1000
end sub

' put the (hidden) shrimp in tube i; flip = big claw on the left
sub placeShrimp(i as integer, flip as boolean)
    t = m.shrimpTubes[i]
    cx = t[0] : cy = t[1] : s = t[2]
    ' only draw above the tube's rim, so the shrimp comes up out of the hole
    m.shrimpClip.clippingRect = [cx - 80, cy - 240, 160, 243]
    g = m.top.FindNode("shrimpG")
    m.shrimpIn.scale = [s, s]
    g.scaleRotateCenter = [60 * s, 118 * s]
    g.rotation = 0
    m.shrimpX = cx - 60 * s
    m.shrimpY = cy
    m.shrimpS = s
    g.translation = [m.shrimpX, cy + 8 * s]
    if flip then
        m.shrimpBody.uri = img("shrimp_l")
        m.shrimpFinger.uri = img("shrimp_finger_l")
        m.shrimpFinger.translation = [18, 8]
        m.shrimpFinger.scaleRotateCenter = [18, 28]
        m.shrimpTip = [30, 20]
        m.shrimpOpen = -0.8
    else
        m.shrimpBody.uri = img("shrimp")
        m.shrimpFinger.uri = img("shrimp_finger")
        m.shrimpFinger.translation = [78, 8]
        m.shrimpFinger.scaleRotateCenter = [6, 28]
        m.shrimpTip = [90, 20]
        m.shrimpOpen = 0.8
    end if
    m.shrimpFinger.rotation = 0
end sub

sub updateShrimp(now as float)
    if now < m.shrimpNext then return
    if m.off["shrimp"] <> invalid then
        m.shrimpNext = now + 30000
        return
    end if
    ' a random tube, never the same one twice in a row
    ti = Int(Rnd(0) * (m.shrimpTubes.Count() - 1))
    if ti >= m.shrimpLast and m.shrimpLast >= 0 then ti = ti + 1
    if m.shrimpLast < 0 then ti = Int(Rnd(0) * m.shrimpTubes.Count())
    m.shrimpLast = ti
    placeShrimp(ti, Rnd(0) < 0.5)
    x = m.shrimpX
    hid = [x, m.shrimpY + 8 * m.shrimpS]
    peek = [x, m.shrimpY - 70 * m.shrimpS]
    full = [x, m.shrimpY - 118 * m.shrimpS]
    o = m.shrimpOpen
    tip = [m.shrimpTip[0] - 32, m.shrimpTip[1] - 32]
    up = [tip[0] + 4, tip[1] - 34]
    if Rnd(0) < 0.3 then
        ' shy: just peeks, looks around and ducks back in
        T = 5.0
        m.shrimpPos.key = [0, 0.14, 0.7, 0.75, 1]
        m.shrimpPos.keyValue = [hid, peek, peek, hid, hid]
        m.shrimpRot.key = [0, 0.2, 0.35, 0.5, 0.62, 1]
        m.shrimpRot.keyValue = [0, 0, 0.12, 0.12, 0, 0]
        m.shrimpSnap.key = [0, 1]
        m.shrimpSnap.keyValue = [0, 0]
        m.shrimpBubO.key = [0, 1]
        m.shrimpBubO.keyValue = [0, 0]
        m.shrimpBubS.key = [0, 1]
        m.shrimpBubS.keyValue = [[0.05, 0.05], [0.05, 0.05]]
        m.shrimpBubP.key = [0, 1]
        m.shrimpBubP.keyValue = [tip, tip]
    else
        ' bold: comes out, looks left and right, snaps its claw twice (pop!), then darts back in
        T = 10.0
        m.shrimpPos.key = [0, 0.07, 0.2, 0.25, 0.76, 0.785, 1]
        m.shrimpPos.keyValue = [hid, peek, peek, full, full, hid, hid]
        m.shrimpRot.key = [0, 0.26, 0.34, 0.46, 0.54, 0.66, 0.73, 1]
        m.shrimpRot.keyValue = [0, 0, 0.16, 0.16, -0.14, -0.14, 0, 0]
        m.shrimpSnap.key = [0, 0.36, 0.41, 0.46, 0.465, 0.56, 0.6, 0.65, 0.655, 1]
        m.shrimpSnap.keyValue = [0, 0, o, o, 0, 0, o, o, 0, 0]
        m.shrimpBubO.key = [0, 0.465, 0.47, 0.54, 0.655, 0.66, 0.73, 1]
        m.shrimpBubO.keyValue = [0, 0, 1, 0, 0, 1, 0, 0]
        m.shrimpBubS.key = [0, 0.465, 0.54, 0.655, 0.73, 1]
        m.shrimpBubS.keyValue = [[0.05, 0.05], [0.05, 0.05], [0.42, 0.42], [0.05, 0.05], [0.42, 0.42], [0.42, 0.42]]
        m.shrimpBubP.key = [0, 0.465, 0.54, 0.655, 0.73, 1]
        m.shrimpBubP.keyValue = [tip, tip, up, tip, up, up]
    end if
    m.shrimpAnim.duration = T
    m.shrimpAnim.control = "start"
    m.shrimpNext = now + T * 1000 + rnd(30, 75) * 1000
end sub

' ---------- bioluminescent plankton (only visible at night) ----------
sub buildPlankton()
    for i = 0 to 69
        p = m.glow.CreateChild("Poster")
        p.id = "pk" + i.ToStr()
        p.uri = img("glow_dot")
        sz = rnd(5, 16)
        p.scale = [sz / 32, sz / 32]
        base = [rnd(-120, 2040), rnd(60, 1060)]
        p.translation = base
        addLoopVec(m.top, p.id, "translation", base, [rnd(-50, 50), rnd(25, 70)], rnd(14, 30), rnd(0, 6.28))
        addLoopFloat(m.top, p.id, "opacity", 0.55, 0.45, rnd(2, 6), rnd(0, 6.28))
    end for
end sub

' ---------- day / night cycle (follows the Roku's local clock) ----------
function currentHour() as float
    if m.lightMode = "day" then return 12.5
    if m.lightMode = "sunset" then return 19.0
    if m.lightMode = "night" then return 23.0
    if m.lightMode = "cycle" then
        h = m.cycleStart + (m.clock.TotalMilliseconds() - m.cycleT0) / 50000.0
        return h - 24 * Int(h / 24)
    end if
    if m.demo then
        h = m.demoStart + (m.clock.TotalMilliseconds() - m.demoT0) / 10000.0
    else
        dt = CreateObject("roDateTime")
        dt.ToLocalTime()
        h = dt.GetHours() + dt.GetMinutes() / 60 + dt.GetSeconds() / 3600 + m.timeOffset
    end if
    return h - 24 * Int(h / 24)
end function

function smoothstep(x as float) as float
    if x < 0 then x = 0
    if x > 1 then x = 1
    return x * x * (3 - 2 * x)
end function

sub updateLight()
    h = currentHour()
    m.hour = h
    ' dawn 5:30-7:30, dusk 18:00-20:00
    if h < 5.5 or h >= 20 then
        day = 0.0
    else if h < 7.5 then
        day = smoothstep((h - 5.5) / 2)
    else if h < 18 then
        day = 1.0
    else
        day = 1 - smoothstep((h - 18) / 2)
    end if
    warm = maxf(0, 1 - Abs(h - 6.6) / 1.2) + maxf(0, 1 - Abs(h - 19.0) / 1.2)
    m.day = day
    m.nightShade.opacity = 0.74 * (1 - day)
    m.nightShade.visible = day < 0.995
    m.warm.opacity = 0.42 * warm
    m.warm.visible = warm > 0.005
    m.rays.opacity = 0.12 + 0.88 * day
    m.caustics.opacity = 0.08 + 0.92 * day
    m.glow.opacity = 1 - day
    m.glow.visible = day < 0.995
end sub

' Remote control (only reaches us when launched as an app, not as the screensaver):
' left/right = shift time by an hour, OK = back to real time, play/fast-forward = 4-minute day demo
sub takeFocus()
    if not m.settingsPanel.visible then m.top.SetFocus(true)
end sub

' ---------- clock / date overlay ----------
sub buildClock()
    m.clockGrp = m.top.FindNode("clockGrp")
    m.cTime = m.top.FindNode("cTime")
    m.cTimeS = m.top.FindNode("cTimeS")
    m.cDate = m.top.FindNode("cDate")
    m.cDateS = m.top.FindNode("cDateS")
    m.clockPos = [[80, 50, "left"], [1080, 50, "right"], [80, 860, "left"], [1080, 860, "right"]]
    m.clockIdx = 0
    m.clockText = ""
    m.clockPhase = ""
    m.clockMoveAt = 0
    m.clockOut = makeClockFade(0.85, 0)
    m.clockIn = makeClockFade(0, 0.85)
end sub

function makeClockFade(a as float, b as float) as object
    anim = m.top.CreateChild("Animation")
    anim.duration = 1.2
    anim.easeFunction = "linear"
    fi = anim.CreateChild("FloatFieldInterpolator")
    fi.key = [0, 1]
    fi.keyValue = [a, b]
    fi.fieldToInterp = "clockGrp.opacity"
    return anim
end function

sub applyClock()
    mode = m.clockMode
    if mode <> "time" and mode <> "date" and mode <> "both" then
        m.clockGrp.visible = false
        return
    end if
    showT = (mode = "time" or mode = "both")
    showD = (mode = "date" or mode = "both")
    m.cTime.visible = showT
    m.cTimeS.visible = showT
    m.cDate.visible = showD
    m.cDateS.visible = showD
    dy = 96
    if not showT then dy = 0
    m.cTime.translation = [0, 0]
    m.cTimeS.translation = [3, 3]
    m.cDate.translation = [0, dy]
    m.cDateS.translation = [3, dy + 3]
    m.clockText = ""
    updateClockText()
    placeClock(Int(Rnd(0) * 4))
    m.clockGrp.opacity = 0.85
    m.clockGrp.visible = true
    m.clockPhase = ""
    m.clockMoveAt = m.clock.TotalMilliseconds() + 150000
end sub

sub placeClock(i as integer)
    m.clockIdx = i
    p = m.clockPos[i]
    m.clockGrp.translation = [p[0], p[1]]
    for each lbl in [m.cTime, m.cTimeS, m.cDate, m.cDateS]
        lbl.horizAlign = p[2]
    end for
end sub

sub updateClockText()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mi = dt.GetMinutes()
    ampm = "AM"
    if h >= 12 then ampm = "PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    ms = mi.ToStr()
    if mi < 10 then ms = "0" + ms
    t = h12.ToStr() + ":" + ms + " " + ampm
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    d = dt.GetWeekday() + ", " + months[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().ToStr()
    if t + d <> m.clockText then
        m.clockText = t + d
        m.cTime.text = t
        m.cTimeS.text = t
        m.cDate.text = d
        m.cDateS.text = d
    end if
end sub

sub tickClock(now as float)
    if not m.clockGrp.visible then return
    updateClockText()
    if m.clockPhase = "" and now >= m.clockMoveAt then
        m.clockOut.control = "start"
        m.clockPhase = "out"
        m.clockMoveAt = now + 1300
    else if m.clockPhase = "out" and now >= m.clockMoveAt then
        placeClock((m.clockIdx + 1 + Int(Rnd(0) * 3)) mod 4)
        m.clockIn.control = "start"
        m.clockPhase = ""
        m.clockMoveAt = now + 150000
    end if
end sub

' ---------- fishing hook: a fish always steals the bait ----------
sub buildFishing()
    g = m.top.FindNode("fishing")
    m.hookGroup = g.CreateChild("Group")
    m.hookGroup.id = "hookGroup"
    m.hookGroup.visible = false
    m.hookGroup.scaleRotateCenter = [24, -1250]
    inner = m.hookGroup.CreateChild("Group")
    inner.scale = [0.8, 0.8]
    line = inner.CreateChild("Rectangle")
    line.width = 2
    line.height = 1600
    line.translation = [29, -1597]
    line.color = "0xDDE8F0FF"
    line.opacity = 0.55
    hook = inner.CreateChild("Poster")
    hook.uri = img("hook")
    m.bait = inner.CreateChild("Poster")
    m.bait.uri = img("bait")
    addLoopFloat(m.top, "hookGroup", "rotation", 0, 0.012, 7, 0)
    m.thief = g.CreateChild("Creature")
    m.thief.id = "thief"
    m.biteTimer = m.top.FindNode("biteTimer")
    m.biteTimer.ObserveField("fire", "onBite")
    m.hookAnim = m.top.CreateChild("Animation")
    m.hookAnim.easeFunction = "outQuad"
    m.hookInterp = m.hookAnim.CreateChild("Vector2DFieldInterpolator")
    m.hookInterp.fieldToInterp = "hookGroup.translation"
    m.fishState = "idle"
    m.fishNext = rnd(50, 100) * 1000
end sub

sub moveHook(keys as object, vals as object, duration as float, ease as string)
    m.hookAnim.control = "stop"
    m.hookAnim.duration = duration
    m.hookAnim.easeFunction = ease
    m.hookInterp.key = keys
    m.hookInterp.keyValue = vals
    m.hookAnim.control = "start"
end sub

sub updateFishing(now as float)
    if m.fishState = "idle" and now >= m.fishNext then
        startFishing(now)
    else if m.fishState = "reel" and now >= m.fishNext then
        moveHook([0, 1], [m.hookPos, [m.hookPos[0], -260]], 4.5, "inQuad")
        m.fishState = "up"
        m.fishNext = now + 5000
    else if m.fishState = "up" and now >= m.fishNext then
        m.hookGroup.visible = false
        m.fishState = "idle"
        m.fishNext = now + rnd(120, 300) * 1000
    end if
end sub

sub startFishing(now as float)
    thieves = []
    for each k in ["tang", "ytang", "angel", "lionfish", "tang"]
        if m.off[k] = invalid then thieves.Push(k)
    end for
    if m.off["hook"] <> invalid or thieves.Count() = 0 then
        m.fishNext = now + 30000
        return
    end if
    hx = rnd(450, 1400)
    hy = rnd(380, 600)
    m.hookPos = [hx, hy]
    m.bait.visible = true
    m.hookGroup.translation = [hx, -260]
    m.hookGroup.visible = true
    moveHook([0, 1], [[hx, -260], [hx, hy]], 6, "outQuad")
    dir = 1
    if Rnd(0) < 0.5 then dir = -1
    duration = rnd(15, 19)
    m.uid = m.uid + 1
    m.thief.callFunc("spawn", { kind: thieves[Int(Rnd(0) * thieves.Count())], uid: m.uid, depth: 0.74, dir: dir, amp: m.amp.near, mode: "steal", hookX: hx + 24 * 0.8, hookY: hy + 90 * 0.8, duration: duration, delay: 7, initial: false, y: hy, x: hx })
    m.biteTimer.duration = 7 + duration * 0.68
    m.biteTimer.control = "start"
    m.fishState = "fishing"
end sub

' the fish grabs the worm: bait gone, the hook jerks, then it's reeled back up
sub onBite()
    m.bait.visible = false
    p = m.hookPos
    moveHook([0, 0.2, 0.45, 0.7, 1], [p, [p[0] + 10, p[1] - 16], [p[0] - 8, p[1] + 6], [p[0] + 4, p[1] - 4], p], 1.0, "linear")
    m.fishState = "reel"
    m.fishNext = m.clock.TotalMilliseconds() + 3000
end sub

' test hooks (launch options)
sub onClockTest()
    m.clockMode = m.top.clockTest
    applyClock()
end sub

sub onFishTest()
    if m.fishState = "idle" then m.fishNext = m.clock.TotalMilliseconds() + 1500
end sub

sub onLowMemory()
    m.lowMem = true
end sub

sub onShrimpTest()
    m.shrimpNext = m.clock.TotalMilliseconds() + 1000
end sub

sub onDiverTest()
    m.slots[m.diverSlot].due = m.clock.TotalMilliseconds() + 1000
end sub

' ---------- settings ----------
sub loadUserSettings()
    s = loadSettings()
    m.off = s.off
    m.clockMode = s.clock
    m.lightMode = s.light
    m.timeOffset = 0
    m.demo = false
    m.lightMode = "auto"
    m.cycleStart = currentHour()
    m.cycleT0 = m.clock.TotalMilliseconds()
    m.lightMode = s.light
end sub

sub openSettingsPanel()
    if m.settingsPanel.visible then return
    m.settingsPanel.visible = true
    m.settingsPanel.callFunc("open", {})
end sub

sub onSettingsDone()
    m.settingsPanel.visible = false
    takeFocus()
    ' and again once the key press that closed the panel has finished being handled
    m.refocus.control = "start"
    loadUserSettings()
    m.eelWrap.visible = (m.off["eel"] = invalid)
    m.shrimpClip.visible = (m.off["shrimp"] = invalid)
    applyClock()
    ' remove animals that were just switched off; their slots refill with allowed ones
    now = m.clock.TotalMilliseconds()
    for i = 0 to m.slots.Count() - 1
        sl = m.slots[i]
        if sl.kind <> invalid and sl.kind <> "" then
            if m.off[sl.kind] <> invalid then
                for each n in sl.nodes
                    n.callFunc("despawn", {})
                end for
                sl.kind = ""
                sl.due = now + 1000
            end if
        end if
    end for
    updateLight()
    showTime()
end sub

' test hook: launch with off=shark,eel to save that animal list and apply it like the settings panel does
sub onSetOff()
    off = {}
    for each k in m.top.setOff.Split(",")
        if k <> "" then off[k] = true
    end for
    s = loadSettings()
    saveSettings({ light: s.light, clock: s.clock, off: off })
    onSettingsDone()
end sub

' launch options from main.brs (testing / previewing a time of day)
sub onStartHour()
    m.lightMode = "auto"
    m.timeOffset = 0
    m.demo = false
    m.timeOffset = m.top.startHour.ToFloat() - currentHour()
    updateLight()
    showTime()
end sub

sub onDemo()
    m.demoStart = currentHour()
    m.demoT0 = m.clock.TotalMilliseconds()
    m.lightMode = "auto"
    m.demo = m.top.demo
    showTime()
end sub

sub showTime()
    h = m.hour
    hh = Int(h)
    mm = Int((h - hh) * 60)
    ampm = "AM"
    if hh >= 12 then ampm = "PM"
    h12 = hh mod 12
    if h12 = 0 then h12 = 12
    ms = mm.ToStr()
    if mm < 10 then ms = "0" + ms
    phase = "Night"
    if m.day >= 0.995 then
        phase = "Day"
    else if m.day > 0.005 and h < 12 then
        phase = "Dawn"
    else if m.day > 0.005 then
        phase = "Dusk"
    end if
    t = h12.ToStr() + ":" + ms + " " + ampm + "  " + phase
    if m.demo then t = t + "  (demo)"
    m.timeLabel.text = t
    if m.labelAnim = invalid then
        m.labelAnim = m.top.CreateChild("Animation")
        m.labelAnim.duration = 4
        li = m.labelAnim.CreateChild("FloatFieldInterpolator")
        li.key = [0, 0.75, 1]
        li.keyValue = [1, 1, 0]
        li.fieldToInterp = "timeLabel.opacity"
    end if
    m.labelAnim.control = "stop"
    m.labelAnim.control = "start"
end sub

' ---------- creatures ----------
sub buildSlots()
    m.slots = []
    m.nodeSlot = {}
    m.layers = {
        far: m.top.FindNode("farCreatures")
        mid: m.top.FindNode("midCreatures")
        near: m.top.FindNode("nearCreatures")
        farBack: m.top.FindNode("farBack")
        jelly: m.top.FindNode("jellyCreatures")
    }
    farKinds = ["tang", "ytang", "angel", "school", "school", "shark", "turtle", "manta", "lionfish"]
    farNight = ["shark", "school", "turtle", "manta", "shark"]
    midKinds = ["tang", "ytang", "angel", "school", "school", "shark", "turtle", "manta", "tang", "angel", "lionfish", "octopus"]
    midNight = ["shark", "octopus", "lionfish", "turtle", "school", "octopus"]
    nearKinds = ["tang", "ytang", "angel", "school", "tang", "ytang", "angel", "lionfish", "octopus"]
    nearNight = ["octopus", "lionfish", "tang", "lionfish"]

    ' rare distant whale, behind the far reef
    addSlot({ layer: "farBack", amp: m.amp.far, kinds: ["whale"], dmin: 0.08, dmax: 0.14, ymin: 220, ymax: 420, first: 12, gapMin: 150, gapMax: 260 })

    addLayer("far", m.amp.far, 6, farKinds, farNight, 0.06, 0.32, 110, 680)

    ' jellyfish live above the night shade so they glow in the dark; more of them at night
    addSlot({ layer: "jelly", amp: m.amp.jelly, kinds: ["jelly"], dmin: 0.2, dmax: 0.3, ymin: 0, ymax: 0, mode: "rise", gapMin: 10, gapMax: 40 })
    addSlot({ layer: "jelly", amp: m.amp.jelly, kinds: ["jelly"], dmin: 0.4, dmax: 0.5, ymin: 0, ymax: 0, mode: "rise", gapMin: 20, gapMax: 60 })
    addSlot({ layer: "jelly", amp: m.amp.jelly, kinds: ["jelly"], dmin: 0.3, dmax: 0.45, ymin: 0, ymax: 0, mode: "rise", gapMin: 5, gapMax: 25, nightOnly: true })
    addSlot({ layer: "jelly", amp: m.amp.jelly, kinds: ["jelly"], dmin: 0.5, dmax: 0.6, ymin: 0, ymax: 0, mode: "rise", gapMin: 5, gapMax: 25, nightOnly: true })

    ' a pod of dolphins racing past near the surface (daytime only)
    addSlot({ layer: "mid", amp: m.amp.mid, kinds: ["dolphin"], pod: 3, dmin: 0.5, dmax: 0.64, ymin: 150, ymax: 320, first: 25, gapMin: 90, gapMax: 200, dayOnly: true })

    addLayer("mid", m.amp.mid, 7, midKinds, midNight, 0.38, 0.66, 120, 760)
    addLayer("near", m.amp.near, 3, nearKinds, nearNight, 0.74, 0.92, 110, 760)

    ' seahorses clinging near the corals
    addSlot({ layer: "near", amp: m.amp.near, kinds: ["seahorse"], dmin: 0.8, dmax: 0.8, ymin: 0, ymax: 0, mode: "bob", home: [1790, 690] })
    addSlot({ layer: "near", amp: m.amp.near, kinds: ["seahorse"], dmin: 0.75, dmax: 0.75, ymin: 0, ymax: 0, mode: "bob", home: [330, 735] })

    ' a scuba diver far in the background, once in a while
    m.diverSlot = m.slots.Count()
    addSlot({ layer: "far", amp: m.amp.far, kinds: ["diver"], dmin: 0.18, dmax: 0.24, ymin: 260, ymax: 520, first: 70, gapMin: 180, gapMax: 360 })

    ' clownfish pair that lives at the anemone
    for i = 0 to 1
        addSlot({ layer: "near", amp: m.amp.near, kinds: ["clown"], dmin: 0.62 + i * 0.05, dmax: 0.62 + i * 0.05, ymin: 0, ymax: 0, mode: "hover", home: [890 - i * 40, 705 - i * 75], range: 110 + i * 60 })
    end for

    ' crabs and a sea star crossing the sand in front
    addSlot({ layer: "near", amp: m.amp.near, kinds: ["crab", "crab", "star"], dmin: 0.85, dmax: 0.9, ymin: 985, ymax: 1030, gapMin: 15, gapMax: 45 })

    ' rare big close-up pass right in front of the camera
    addSlot({ layer: "near", amp: m.amp.near, kinds: ["shark", "turtle", "manta", "shark", "dolphin"], nightKinds: ["shark", "octopus", "shark"], dmin: 0.9, dmax: 1.0, ymin: 200, ymax: 560, first: 35, gapMin: 70, gapMax: 150 })

    for i = 0 to m.slots.Count() - 1
        sl = m.slots[i]
        if sl.first <> invalid then
            sl.due = sl.first * 1000
        else
            spawnSlot(i, true)
        end if
    end for
end sub

sub addLayer(layer as string, amp as float, count as integer, kinds as object, nightKinds as object, dmin as float, dmax as float, ymin as float, ymax as float)
    ' each slot gets its own slice of the depth range, so nearer slots draw on top
    for i = 0 to count - 1
        a = dmin + (dmax - dmin) * i / count
        b = dmin + (dmax - dmin) * (i + 1) / count
        addSlot({ layer: layer, amp: amp, kinds: kinds, nightKinds: nightKinds, rest: 0.45, dmin: a, dmax: b, ymin: ymin, ymax: ymax, gapMin: 1, gapMax: 9 })
    end for
end sub

sub addSlot(sl as object)
    idx = m.slots.Count()
    count = 1
    if sl.pod <> invalid then count = sl.pod
    sl.nodes = []
    for k = 0 to count - 1
        node = m.layers[sl.layer].CreateChild("Creature")
        node.id = "slot" + idx.ToStr() + "_" + k.ToStr()
        m.nodeSlot[node.id] = idx
        node.ObserveField("done", "onCreatureDone")
        sl.nodes.Push(node)
    end for
    sl.due = 0
    sl.pending = 0
    sl.kind = ""
    if sl.mode = invalid then sl.mode = "cross"
    m.slots.Push(sl)
end sub

sub spawnSlot(i as integer, initial as boolean)
    sl = m.slots[i]
    now = m.clock.TotalMilliseconds()
    ' the Roku reported low memory: keep about half of the animal slots empty
    if m.lowMem = true and i mod 2 = 1 then
        sl.due = now + 60000
        return
    end if
    night = m.day < 0.35
    if (night and sl.dayOnly <> invalid) or (not night and sl.nightOnly <> invalid) then
        sl.due = now + 30000
        return
    end if
    if night and sl.rest <> invalid then
        if Rnd(0) < sl.rest then
            ' reef fish shelter at night: this slot stays empty for a while
            sl.due = now + rnd(10, 30) * 1000
            return
        end if
    end if
    kinds = sl.kinds
    if night and sl.nightKinds <> invalid then kinds = sl.nightKinds
    ' only animals that are switched on in settings
    allowed = []
    for each k in kinds
        if m.off[k] = invalid then allowed.Push(k)
    end for
    if allowed.Count() = 0 then
        sl.kind = ""
        sl.due = now + 5000
        return
    end if
    kind = allowed[Int(Rnd(0) * allowed.Count())]
    sl.kind = kind
    dir = 1
    if Rnd(0) < 0.5 then dir = -1
    y = rnd(sl.ymin, sl.ymax)
    if kind = "shark" or kind = "turtle" or kind = "manta" or kind = "whale" or kind = "dolphin" then
        y = rnd(sl.ymin + 40, sl.ymin + (sl.ymax - sl.ymin) * 0.7)
    end if
    sl.pending = sl.nodes.Count()
    for k = 0 to sl.nodes.Count() - 1
        m.uid = m.uid + 1
        cfg = {
            kind: kind
            uid: m.uid
            depth: rnd(sl.dmin, sl.dmax)
            dir: dir
            amp: sl.amp
            y: y + k * rnd(-55, 55)
            x: rnd(150, 1770)
            mode: sl.mode
            initial: initial
            delay: k * rnd(0.4, 0.9)
            home: sl.home
            range: sl.range
        }
        sl.nodes[k].callFunc("spawn", cfg)
    end for
end sub

sub onCreatureDone(event as object)
    node = event.GetRoSGNode()
    sl = m.slots[m.nodeSlot[node.id]]
    sl.pending = sl.pending - 1
    if sl.pending <= 0 then sl.due = m.clock.TotalMilliseconds() + rnd(sl.gapMin, sl.gapMax) * 1000
end sub

sub onTick()
    updateLight()
    now = m.clock.TotalMilliseconds()
    tickClock(now)
    updateFishing(now)
    updateShrimp(now)
    for i = 0 to m.slots.Count() - 1
        sl = m.slots[i]
        if sl.due > 0 and now >= sl.due then
            sl.due = 0
            spawnSlot(i, false)
        end if
    end for
end sub
