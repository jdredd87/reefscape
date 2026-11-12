' Shared helpers (included by OceanScene and Creature)

function rnd(a as float, b as float) as float
    return a + (b - a) * Rnd(0)
end function

function maxf(a as float, b as float) as float
    if a > b then return a
    return b
end function

function img(name as string) as string
    return "pkg:/images/ocean/" + name + ".png"
end function

' Set a poster's image. 720p Rokus draw the whole scene at 2/3 size, so there large images are
' decoded at that size: less than half the texture memory and no visible difference.
' loadWidth/loadHeight are given in the app's 1080p units and Roku converts them to 720p itself,
' so the image's own size is passed. The poster keeps that size, so the layout is unchanged.
sub setImg(p as object, name as string)
    if m.hdLoad = invalid then
        ui = CreateObject("roDeviceInfo").GetUIResolution()
        m.hdLoad = (ui <> invalid and ui.height <> invalid and ui.height <= 720)
        if m.hdLoad then m.imgSizes = imageSizes()
    end if
    if m.hdLoad then
        sz = m.imgSizes[name]
        ' repeating tiles (surface, caustics) keep full size: shrinking softens their edges into visible joins
        tile = (name = "surface" or Left(name, 8) = "caustics")
        if sz <> invalid and sz[0] * sz[1] >= 20000 and not tile then
            if p.width = 0 then p.width = sz[0]
            if p.height = 0 then p.height = sz[1]
            p.loadDisplayMode = "scaleToFit"
            p.loadWidth = sz[0]
            p.loadHeight = sz[1]
        end if
    end if
    p.uri = img(name)
end sub

function hex2(v as float) as string
    h = "0123456789ABCDEF"
    n = Int(v)
    if n < 0 then n = 0
    if n > 255 then n = 255
    return Mid(h, Int(n / 16) + 1, 1) + Mid(h, (n mod 16) + 1, 1)
end function

function rgb(r as float, g as float, b as float) as string
    return "0x" + hex2(r) + hex2(g) + hex2(b) + "FF"
end function

' Underwater colour shift: far things are bluer and darker. depth 0 = far, 1 = near
function tintFor(depth as float, dark = 1.0 as float) as string
    k = 0.45 + 0.55 * depth
    return rgb((105 + 150 * k) * dark, (160 + 95 * k) * dark, (195 + 60 * k) * dark)
end function

' Looping animation that swings a float field: center + amp * sin(2*pi*t + phase)
function addLoopFloat(parent as object, targetId as string, field as string, center as float, amp as float, period as float, phase as float) as object
    anim = parent.CreateChild("Animation")
    anim.repeat = true
    anim.duration = period
    anim.easeFunction = "linear"
    interp = anim.CreateChild("FloatFieldInterpolator")
    keys = []
    vals = []
    for i = 0 to 16
        t = i / 16
        keys.Push(t)
        vals.Push(center + amp * Sin(t * 6.2831853 + phase))
    end for
    interp.key = keys
    interp.keyValue = vals
    interp.fieldToInterp = targetId + "." + field
    anim.control = "start"
    return anim
end function

' Same for 2D fields (translation, scale): base + amp * sin(2*pi*t + phase)
function addLoopVec(parent as object, targetId as string, field as string, base as object, amp as object, period as float, phase as float) as object
    anim = parent.CreateChild("Animation")
    anim.repeat = true
    anim.duration = period
    anim.easeFunction = "linear"
    interp = anim.CreateChild("Vector2DFieldInterpolator")
    keys = []
    vals = []
    for i = 0 to 16
        t = i / 16
        s = Sin(t * 6.2831853 + phase)
        keys.Push(t)
        vals.Push([base[0] + amp[0] * s, base[1] + amp[1] * s])
    end for
    interp.key = keys
    interp.keyValue = vals
    interp.fieldToInterp = targetId + "." + field
    anim.control = "start"
    return anim
end function
