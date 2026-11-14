sub init()
    m.anims = []
    m.swim = invalid
    m.root = invalid
    m.gen = 0
    m.specs = getSpecs()
end sub

sub clearAll()
    if m.swim <> invalid then m.swim.UnobserveField("state")
    for each a in m.anims
        a.control = "stop"
    end for
    m.anims = []
    m.swim = invalid
    m.root = invalid
    m.top.fleeable = false
    m.top.RemoveChildrenIndex(m.top.GetChildCount(), 0)
end sub

' A shark is coming: dart away from it (params.awayY = -1 up / 1 down; params.turn = turn round first).
' The creature is rebuilt from where it is now and races off the screen, then reports done as usual.
function flee(params as object) as boolean
    if not m.top.fleeable or m.root = invalid then return false
    t = m.root.translation
    spec = m.specs[m.cfg.kind]
    ' only from on screen (or just at its edge): a fish waiting off screen must not race back in
    x = t[0] + spec.cx
    if x < -60 or x > 1980 then return false
    cfg = {}
    cfg.Append(m.cfg)
    cfg.mode = "flee"
    cfg.delay = 0
    cfg.initial = false
    cfg.fleeY = params.awayY
    cfg.turned = (params.turn = true)
    if cfg.turned then cfg.dir = -m.cfg.dir
    cfg.startPos = [t[0] + spec.cx, t[1] + spec.cy]
    spawn(cfg)
    return true
end function

' Remove the creature (used when its animal is switched off in settings)
function despawn(params as object) as boolean
    clearAll()
    return true
end function

' cfg: kind, uid, depth (0 far..1 near), dir (1 right / -1 left), amp (layer parallax),
'      y (screen y), x, mode ("cross" | "hover" | "rise"), initial, delay, home, range
function spawn(cfg as object) as boolean
    clearAll()
    spec = m.specs[cfg.kind]
    m.gen = m.gen + 1
    p = "c" + cfg.uid.ToStr() + "_" + m.gen.ToStr() + "_"
    depth = cfg.depth
    persp = 0.22 + 0.78 * depth
    ' keep the same size and speed if this is the same animal starting to flee
    if cfg.sizeK = invalid then cfg.sizeK = rnd(0.88, 1.12)
    if cfg.speedK = invalid then cfg.speedK = rnd(0.85, 1.15)
    s = spec.scale * persp * cfg.sizeK
    dir = cfg.dir
    if spec.noFlip <> invalid then dir = 1
    sy = 1.0
    if spec.sy <> invalid then sy = spec.sy
    tint = tintFor(depth)
    speedK = cfg.speedK
    phase = rnd(0, 6.28)
    m.cfg = cfg
    m.top.dir = dir
    ' fleeing animals beat their tails much faster
    animK = speedK
    if cfg.mode = "flee" then animK = speedK * 2.6

    root = m.top.CreateChild("Group")
    m.root = root
    root.id = p + "root"
    root.scaleRotateCenter = [spec.cx, spec.cy]
    root.scale = [s, s * sy]
    inner = root.CreateChild("Group")
    inner.id = p + "inner"
    inner.scaleRotateCenter = [spec.cx, spec.cy]

    if cfg.mode = "hover" then
        ' both facings are built; the hover animation cross-fades between them at each turn
        gR = inner.CreateChild("Group")
        gR.id = p + "gR"
        gL = inner.CreateChild("Group")
        gL.id = p + "gL"
        gL.opacity = 0
        buildParts(gR, spec, p + "R", depth, 1, phase, speedK)
        buildParts(gL, spec, p + "L", depth, -1, phase, speedK)
    else if spec.school <> invalid then
        spread = 1.0
        if cfg.mode = "flee" then spread = 1.7
        buildSchool(inner, spec, p, tint, dir, spread)
    else
        buildParts(inner, spec, p, depth, dir, phase, animK)
    end if

    if spec.sway <> invalid then m.anims.Push(addLoopFloat(m.top, inner.id, "rotation", 0, spec.sway, spec.swayPeriod / animK, phase + 1.6))
    if spec.flap <> invalid then m.anims.Push(addLoopVec(m.top, inner.id, "scale", [1, 0.8], [0, 0.2], spec.flap, phase))
    if spec.exhale <> invalid then addExhale(inner, spec, p, dir, tint)
    if spec.hop <> invalid then m.anims.Push(addLoopVec(m.top, inner.id, "translation", [0, 0], [0, -4], spec.hop, phase))
    ' crawlers that may go either way (noFlip only fixes the image), moving in surges: speed swings
    ' between 0.2x and 1.8x once per stride of spec.crawl seconds instead of a steady glide
    moveDir = dir
    if spec.crawl <> invalid then
        moveDir = cfg.dir
        period = spec.crawl / speedK
        a = 0.8 * (spec.speed * persp * speedK) * period / 6.2831853 / s
        m.anims.Push(addLoopVec(m.top, inner.id, "translation", [0, 0], [a * moveDir, 0], period, phase))
    end if

    if cfg.mode = "hover" then
        startHover(cfg, spec, root, p, s * sy, s)
    else if cfg.mode = "rise" then
        startRise(cfg, spec, root, s, persp, speedK)
    else if cfg.mode = "bob" then
        startBob(cfg, spec, root)
    else if cfg.mode = "steal" then
        startSteal(cfg, spec, root, s, dir)
    else if cfg.mode = "flee" then
        startFlee(cfg, spec, root, s, sy, dir, persp, speedK)
    else
        startCross(cfg, spec, root, s, moveDir, persp, speedK)
        if spec.prey <> invalid then m.top.fleeable = true
    end if
    return true
end function

' Dart away from a shark: a burst of speed that eases off, veering up or down, out of the screen
sub startFlee(cfg as object, spec as object, root as object, s as float, sy as float, dir as integer, persp as float, speedK as float)
    halfExt = maxf(spec.maxX - spec.cx, spec.cx - spec.minX) * s
    x0 = cfg.startPos[0] - spec.cx
    y0 = cfg.startPos[1] - spec.cy
    if dir = 1 then ex = 1920 + cfg.amp + 40 - spec.cx + halfExt else ex = -cfg.amp - 40 - spec.cx - halfExt
    dy = cfg.fleeY * rnd(150, 260) * persp
    ' stay in this layer's own swimming band: below it the reef and sand of the nearer layers are drawn
    ' in front, and a fish diving there vanishes behind them. With no room on the chosen side, go the other way.
    lo = 70.0
    hi = 900.0
    if cfg.ymin <> invalid then lo = maxf(lo, cfg.ymin)
    if cfg.ymax <> invalid then hi = cfg.ymax
    yc = cfg.startPos[1]
    if dy > 0 and hi - yc < 60 then dy = -dy
    if dy < 0 and yc - lo < 60 then dy = -dy
    if yc + dy > hi then dy = hi - yc
    if yc + dy < lo then dy = lo - yc
    dist = Abs(ex - x0)
    if dist < 50 then dist = 50
    ' average speed 1.9x normal; with the ease-out the first moment is nearly 4x
    duration = dist / (spec.speed * persp * speedK * 1.9)
    keys = []
    pts = []
    rots = []
    sgn = 0
    if dy > 0 then sgn = 1
    if dy < 0 then sgn = -1
    for i = 0 to 16
        t = i / 16
        keys.Push(t)
        u = 1 - (1 - t) * (1 - t)
        v = 1 - (1 - t) ^ 6
        pts.Push([x0 + (ex - x0) * u, y0 + dy * v])
        rots.Push(sgn * dir * 0.38 * (1 - t) ^ 3)
    end for
    root.translation = pts[0]
    root.rotation = rots[0]
    anim = m.top.CreateChild("Animation")
    anim.duration = duration
    anim.easeFunction = "linear"
    posI = anim.CreateChild("Vector2DFieldInterpolator")
    posI.key = keys
    posI.keyValue = pts
    posI.fieldToInterp = root.id + ".translation"
    rotI = anim.CreateChild("FloatFieldInterpolator")
    rotI.key = keys
    rotI.keyValue = rots
    rotI.fieldToInterp = root.id + ".rotation"
    if cfg.turned then
        ' a quick turn: squeezed to a sliver, then full width facing the other way
        k = 0.2 / duration
        if k > 0.3 then k = 0.3
        sI = anim.CreateChild("Vector2DFieldInterpolator")
        sI.key = [0, k, 1]
        sI.keyValue = [[s * 0.1, s * sy], [s, s * sy], [s, s * sy]]
        sI.fieldToInterp = root.id + ".scale"
        root.scale = [s * 0.1, s * sy]
    end if
    watch(anim)
end sub

' Adds the creature's posters. Facing left uses the pre-mirrored "_l" images, with positions/pivots mirrored around cx.
sub buildParts(parent as object, spec as object, p as string, depth as float, dir as integer, phase as float, speedK as float)
    suffix = ""
    if dir = -1 then suffix = "_l"
    tint = tintFor(depth)
    for each part in spec.parts
        x = part.x
        px = part.px
        if dir = -1 then
            x = 2 * spec.cx - part.x - part.w
            if part.px <> invalid then px = part.w - part.px
        end if
        po = parent.CreateChild("Poster")
        po.id = p + part.id
        setImg(po, part.uri + suffix)
        po.translation = [x, part.y]
        if part.dark <> invalid then po.blendColor = tintFor(depth, part.dark) else po.blendColor = tint
        if part.px <> invalid then po.scaleRotateCenter = [px, part.py]
        base = 0.0
        if part.rot <> invalid then
            base = part.rot
            po.rotation = base
        end if
        if part.op <> invalid then po.opacity = part.op
        ' half-size images (part.h = full height): drawn at full size via width/height
        if part.h <> invalid then
            po.width = part.w
            po.height = part.h
        end if
        off = 0.0
        if part.po <> invalid then off = part.po
        kind = ""
        if part.anim <> invalid then kind = part.anim
        if kind = "rot" then
            m.anims.Push(addLoopFloat(m.top, po.id, "rotation", base, part.amp, part.period / speedK, phase + off))
            ' rotating parts can also stretch (a sea star's arm reaching and pulling in); sph = its phase lead
            if part.samp <> invalid then
                sph = 0.0
                if part.sph <> invalid then sph = part.sph
                m.anims.Push(addLoopVec(m.top, po.id, "scale", [1, 1], part.samp, part.period / speedK, phase + off + sph))
            end if
        else if kind = "scale" then
            m.anims.Push(addLoopVec(m.top, po.id, "scale", [1, 1], part.samp, part.period, phase + off))
        end if
    end for
end sub

sub buildSchool(inner as object, spec as object, p as string, tint as string, dir as integer, spread as float)
    fishImg = "school_fish"
    if dir = -1 then fishImg = "school_fish_l"
    for i = 0 to spec.school - 1
        fx = spec.cx + rnd(-190, 130) * dir * spread - 61
        fy = spec.cy + rnd(-80, 80) * spread - 23
        po = inner.CreateChild("Poster")
        po.id = p + "f" + i.ToStr()
        setImg(po, fishImg)
        po.translation = [fx, fy]
        po.blendColor = tint
        m.anims.Push(addLoopVec(m.top, po.id, "translation", [fx, fy], [rnd(5, 12), rnd(4, 9)], rnd(1.6, 3.2), rnd(0, 6.28)))
    end for
end sub

' Swim across the screen and then report done
sub startCross(cfg as object, spec as object, root as object, s as float, dir as integer, persp as float, speedK as float)
    halfExt = maxf(spec.maxX - spec.cx, spec.cx - spec.minX) * s
    leftX = -cfg.amp - 40 - spec.cx - halfExt
    rightX = 1920 + cfg.amp + 40 - spec.cx + halfExt
    if dir = 1 then
        sx = leftX
        ex = rightX
    else
        sx = rightX
        ex = leftX
    end if
    if cfg.initial = true then sx = rnd(100, 1700) - spec.cx

    y0 = cfg.y - spec.cy
    y1 = y0 + rnd(-90, 90)
    if spec.flat <> invalid then y1 = y0
    dist = Abs(ex - sx)
    speed = spec.speed * persp * speedK
    bob = spec.bob * persp
    waves = dist / rnd(600, 1000)
    ph = rnd(0, 6.28)
    w = waves * 6.2831853

    keys = []
    pts = []
    rots = []
    n = 24
    for i = 0 to n
        t = i / n
        keys.Push(t)
        pts.Push([sx + (ex - sx) * t, y0 + (y1 - y0) * t + bob * Sin(t * w + ph)])
        slope = ((y1 - y0) + bob * w * Cos(t * w + ph)) / dist
        a = Atn(-slope) * dir
        if a > 0.25 then a = 0.25
        if a < -0.25 then a = -0.25
        rots.Push(a)
    end for
    root.translation = pts[0]
    root.rotation = rots[0]

    anim = m.top.CreateChild("Animation")
    anim.duration = dist / speed
    anim.easeFunction = "linear"
    anim.repeat = false
    if cfg.delay <> invalid then anim.delay = cfg.delay
    posI = anim.CreateChild("Vector2DFieldInterpolator")
    posI.key = keys
    posI.keyValue = pts
    posI.fieldToInterp = root.id + ".translation"
    rotI = anim.CreateChild("FloatFieldInterpolator")
    rotI.key = keys
    rotI.keyValue = rots
    rotI.fieldToInterp = root.id + ".rotation"
    watch(anim)
end sub

' Drift upward (jellyfish)
sub startRise(cfg as object, spec as object, root as object, s as float, persp as float, speedK as float)
    x0 = cfg.x - spec.cx
    sy = 1180.0
    if cfg.initial = true then sy = rnd(150, 900)
    ey = -400.0 - spec.cy * s
    drift = rnd(-160, 160)
    dist = sy - ey
    keys = []
    pts = []
    ph = rnd(0, 6.28)
    for i = 0 to 16
        t = i / 16
        keys.Push(t)
        pts.Push([x0 + drift * t + 30 * persp * Sin(t * 9 + ph), sy + (ey - sy) * t])
    end for
    root.translation = pts[0]
    anim = m.top.CreateChild("Animation")
    anim.duration = dist / (spec.speed * persp * speedK)
    anim.easeFunction = "linear"
    if cfg.delay <> invalid then anim.delay = cfg.delay
    posI = anim.CreateChild("Vector2DFieldInterpolator")
    posI.key = keys
    posI.keyValue = pts
    posI.fieldToInterp = root.id + ".translation"
    watch(anim)
end sub

' Patrol back and forth around a home point forever, turning at each end (clownfish at the anemone)
sub startHover(cfg as object, spec as object, root as object, p as string, sY as float, s as float)
    hx = cfg.home[0] - spec.cx
    hy = cfg.home[1] - spec.cy
    r = cfg.range
    a = [hx - r, hy + rnd(-25, 25)]
    b = [hx + r, hy + rnd(-25, 25)]
    keys = [0, 0.12, 0.24, 0.36, 0.46, 0.5, 0.62, 0.74, 0.86, 0.96, 1]
    pts = [a, [hx - r * 0.5, a[1] - 22], [hx, hy - 34], [hx + r * 0.5, b[1] - 18], b, [b[0] + 6, b[1] + 4], [hx + r * 0.5, b[1] + 16], [hx, hy + 20], [hx - r * 0.5, a[1] + 14], a, a]
    anim = m.top.CreateChild("Animation")
    anim.duration = rnd(13, 18)
    anim.easeFunction = "linear"
    anim.repeat = true
    posI = anim.CreateChild("Vector2DFieldInterpolator")
    posI.key = keys
    posI.keyValue = pts
    posI.fieldToInterp = root.id + ".translation"
    ' turning: squeeze to a sliver, swap facing, expand again
    sk = [0, 0.45, 0.475, 0.5, 0.95, 0.975, 1]
    si = anim.CreateChild("Vector2DFieldInterpolator")
    si.key = sk
    si.keyValue = [[s, sY], [s, sY], [s * 0.08, sY], [s, sY], [s, sY], [s * 0.08, sY], [s, sY]]
    si.fieldToInterp = root.id + ".scale"
    ok = [0, 0.474, 0.476, 0.974, 0.976, 1]
    opR = anim.CreateChild("FloatFieldInterpolator")
    opR.key = ok
    opR.keyValue = [1, 1, 0, 0, 1, 1]
    opR.fieldToInterp = p + "gR.opacity"
    opL = anim.CreateChild("FloatFieldInterpolator")
    opL.key = ok
    opL.keyValue = [0, 0, 1, 1, 0, 0]
    opL.fieldToInterp = p + "gL.opacity"
    root.translation = a
    anim.control = "start"
    m.anims.Push(anim)
end sub

' Bursts of exhaled bubbles rising from the diver's regulator
sub addExhale(inner as object, spec as object, p as string, dir as integer, tint as string)
    ex = spec.exhale[0]
    if dir = -1 then ex = 2 * spec.cx - ex
    for i = 0 to 4
        b = inner.CreateChild("Poster")
        b.id = p + "bub" + i.ToStr()
        setImg(b, "bubble")
        sz = rnd(14, 26)
        b.scale = [sz / 64, sz / 64]
        b.blendColor = tint
        b.opacity = 0
        anim = m.top.CreateChild("Animation")
        anim.repeat = true
        anim.duration = 4.5
        anim.delay = i * 0.18
        anim.easeFunction = "linear"
        x0 = ex + rnd(-6, 6)
        ti = anim.CreateChild("Vector2DFieldInterpolator")
        ti.key = [0, 0.6, 1]
        ti.keyValue = [[x0, spec.exhale[1]], [x0 + rnd(-20, 20), spec.exhale[1] - 220], [x0 + rnd(-20, 20), spec.exhale[1] - 220]]
        ti.fieldToInterp = b.id + ".translation"
        oi = anim.CreateChild("FloatFieldInterpolator")
        oi.key = [0, 0.04, 0.5, 0.6, 1]
        oi.keyValue = [0, 0.9, 0.4, 0, 0]
        oi.fieldToInterp = b.id + ".opacity"
        anim.control = "start"
        m.anims.Push(anim)
    end for
end sub

' Sneak up to a baited hook, hesitate, dart in to grab the bait (at 68% of the time) and race away
sub startSteal(cfg as object, spec as object, root as object, s as float, dir as integer)
    halfExt = maxf(spec.maxX - spec.cx, spec.cx - spec.minX) * s
    hx = cfg.hookX - spec.cx - dir * (spec.maxX - 12 - spec.cx) * s
    hy = cfg.hookY - spec.cy
    leftX = -cfg.amp - 40 - spec.cx - halfExt
    rightX = 1920 + cfg.amp + 40 - spec.cx + halfExt
    if dir = 1 then
        sx = leftX
        ex = rightX
    else
        sx = rightX
        ex = leftX
    end if
    w = hx - dir * 150
    keys = [0, 0.45, 0.5, 0.55, 0.6, 0.64, 0.68, 1]
    pts = [[sx, hy + 70], [w, hy + 12], [w - dir * 30, hy + 16], [w + dir * 20, hy + 6], [w - dir * 15, hy + 10], [w, hy + 8], [hx, hy], [ex, hy - 90]]
    root.translation = pts[0]
    anim = m.top.CreateChild("Animation")
    anim.duration = cfg.duration
    anim.easeFunction = "linear"
    if cfg.delay <> invalid then anim.delay = cfg.delay
    posI = anim.CreateChild("Vector2DFieldInterpolator")
    posI.key = keys
    posI.keyValue = pts
    posI.fieldToInterp = root.id + ".translation"
    watch(anim)
end sub

' Stay at a home spot, gently bobbing and swaying (seahorses)
sub startBob(cfg as object, spec as object, root as object)
    home = [cfg.home[0] - spec.cx, cfg.home[1] - spec.cy]
    root.translation = home
    m.anims.Push(addLoopVec(m.top, root.id, "translation", home, [rnd(4, 9), rnd(10, 18)], rnd(5, 8), rnd(0, 6.28)))
    m.anims.Push(addLoopFloat(m.top, root.id, "rotation", 0, rnd(0.04, 0.08), rnd(6, 9), rnd(0, 6.28)))
end sub

sub watch(anim as object)
    m.swim = anim
    m.anims.Push(anim)
    anim.ObserveField("state", "onSwimState")
    anim.control = "start"
end sub

sub onSwimState()
    if m.swim <> invalid and m.swim.state = "stopped" then
        m.swim.UnobserveField("state")
        m.swim = invalid
        ' finished: it waits off screen until its slot reuses it, so it must not flee any more
        ' (it would race back across the screen and vanish when the slot spawns the next animal)
        m.top.fleeable = false
        m.top.done = true
    end if
end sub
