' Creature definitions. All artwork faces right; parts are listed back-to-front.
'   x,y,w    = part position and image width inside the creature (w is used to mirror it)
'   px,py    = pivot (joint) for rotation/scale animation
'   anim     = "rot" (swing rotation by amp) or "scale" (pulse scale by samp)
'   po       = phase offset for that part's motion (radians); op = fixed opacity
'   prey     = darts away from sharks
'   flat     = keeps a level path (crawlers); hop = little bounce period; noFlip = never mirrored
'   cx,cy    = creature centre; minX/maxX = horizontal extent (for off-screen maths)
'   scale    = size at depth 1 (closest); speed = pixels/second at depth 1; bob = vertical wave
function getSpecs() as object
    return {
        clown: { cx: 117, cy: 72, minX: -48, maxX: 235, scale: 0.85, speed: 100, bob: 30, parts: [
            { id: "tail", uri: "clown_tail", w: 72, x: -48, y: 24, px: 70, py: 50, anim: "rot", amp: 0.3, period: 0.45 }
            { id: "body", uri: "clown_body", w: 235, x: 0, y: 0 }
            { id: "pec", uri: "clown_pec", w: 32, x: 126, y: 74, px: 26, py: 11, anim: "rot", amp: 0.3, period: 0.4, po: 1.0, samp: [-0.3, 0], sph: 1.57 }
        ] }
        tang: { prey: true, cx: 130, cy: 90, minX: -46, maxX: 262, scale: 0.85, speed: 120, bob: 35, parts: [
            { id: "tail", uri: "tang_tail", w: 82, x: -46, y: 34, px: 80, py: 56, anim: "rot", amp: 0.25, period: 0.5 }
            { id: "body", uri: "tang_body", w: 262, x: 0, y: 0 }
        ] }
        ytang: { prey: true, cx: 110, cy: 100, minX: -36, maxX: 222, scale: 0.8, speed: 105, bob: 30, parts: [
            { id: "tail", uri: "ytang_tail", w: 72, x: -36, y: 45, px: 70, py: 55, anim: "rot", amp: 0.25, period: 0.5 }
            { id: "body", uri: "ytang_body", w: 222, x: 0, y: 0 }
        ] }
        angel: { prey: true, cx: 125, cy: 105, minX: -34, maxX: 250, scale: 0.8, speed: 90, bob: 30, parts: [
            { id: "tail", uri: "angel_tail", w: 72, x: -34, y: 55, px: 70, py: 50, anim: "rot", amp: 0.22, period: 0.6 }
            { id: "body", uri: "angel_body", w: 250, x: 0, y: 0 }
        ] }
        shark: { cx: 400, cy: 165, minX: -220, maxX: 850, scale: 0.75, speed: 150, bob: 40, sway: 0.015, swayPeriod: 1.5, parts: [
            { id: "tail", uri: "shark_tail", w: 272, x: -220, y: 4, px: 270, py: 162, anim: "rot", amp: 0.16, period: 1.5 }
            { id: "body", uri: "shark_body", w: 850, x: 0, y: 0 }
        ] }
        turtle: { cx: 300, cy: 160, minX: -22, maxX: 590, scale: 0.7, speed: 65, bob: 35, parts: [
            { id: "ffar", uri: "turtle_flipper", w: 290, x: 153, y: 134, px: 275, py: 30, anim: "rot", amp: 0.38, period: 3.4, po: 0.4, dark: 0.6 }
            { id: "rear", uri: "turtle_rear", w: 132, x: -22, y: 158, px: 122, py: 14, anim: "rot", amp: 0.15, period: 3.4, po: 1.5 }
            { id: "body", uri: "turtle_body", w: 590, x: 0, y: 0 }
            { id: "fnear", uri: "turtle_flipper", w: 290, x: 128, y: 146, px: 275, py: 30, anim: "rot", amp: 0.38, period: 3.4 }
        ] }
        manta: { cx: 265, cy: 210, minX: 0, maxX: 530, sy: 0.62, scale: 0.75, speed: 85, bob: 50, flap: 4.0, parts: [
            { id: "body", uri: "manta", w: 530, x: 0, y: 0 }
        ] }
        jelly: { cx: 100, cy: 150, minX: 0, maxX: 200, scale: 0.7, speed: 22, bob: 0, noFlip: true, parts: [
            { id: "glow", uri: "jelly_glow", w: 260, x: -30, y: -40, op: 0.45 }
            { id: "tent", uri: "jelly_tentacles", w: 200, x: 0, y: 98, px: 100, py: 0, anim: "scale", samp: [-0.05, 0.06], period: 2.6 }
            { id: "bell", uri: "jelly_bell", w: 200, x: 0, y: 0, px: 100, py: 110, anim: "scale", samp: [0.1, -0.13], period: 2.6 }
        ] }
        whale: { cx: 650, cy: 220, minX: 0, maxX: 1300, scale: 1.7, speed: 55, bob: 25, sway: 0.015, swayPeriod: 9, parts: [
            { id: "body", uri: "whale", w: 1300, h: 430, x: 0, y: 0 }
        ] }
        lionfish: { cx: 140, cy: 110, minX: -34, maxX: 280, scale: 0.8, speed: 45, bob: 20, parts: [
            { id: "tail", uri: "lion_tail", w: 80, x: -34, y: 75, px: 78, py: 45, anim: "rot", amp: 0.18, period: 0.9 }
            { id: "body", uri: "lion_body", w: 280, x: 0, y: 0 }
            { id: "fin", uri: "lion_fin", w: 200, x: -20, y: 110, px: 190, py: 20, anim: "rot", amp: 0.12, period: 2.6 }
        ] }
        octopus: { cx: -30, cy: 90, minX: -244, maxX: 170, scale: 0.75, speed: 55, bob: 30, parts: [
            { id: "arms", uri: "octo_arms", w: 300, x: -244, y: 20, px: 296, py: 80, anim: "scale", samp: [-0.2, 0.1], period: 1.8 }
            { id: "body", uri: "octo_body", w: 170, x: 0, y: 0, px: 110, py: 70, anim: "scale", samp: [0.06, -0.05], period: 1.8, po: 0.6 }
        ] }
        dolphin: { cx: 230, cy: 110, minX: -88, maxX: 540, scale: 0.8, speed: 260, bob: 70, sway: 0.02, swayPeriod: 0.8, parts: [
            { id: "tail", uri: "dolphin_tail", w: 140, x: -88, y: 59, px: 136, py: 62, anim: "rot", amp: 0.3, period: 0.8 }
            { id: "body", uri: "dolphin_body", w: 540, x: 0, y: 0 }
        ] }
        seahorse: { cx: 65, cy: 115, minX: -10, maxX: 130, scale: 0.85, speed: 0, bob: 0, sway: 0.07, swayPeriod: 5, parts: [
            { id: "fin", uri: "seahorse_fin", w: 44, x: -10, y: 78, px: 42, py: 22, anim: "scale", samp: [-0.4, 0], period: 0.25 }
            { id: "body", uri: "seahorse", w: 130, x: 0, y: 0 }
        ] }
        crab: { cx: 110, cy: 90, minX: -41, maxX: 261, scale: 0.5, speed: 40, bob: 0, flat: true, noFlip: true, hop: 0.35, parts: [
            { id: "legsL", uri: "crab_legs", w: 100, x: -41, y: 72, px: 96, py: 20, anim: "rot", amp: 0.22, period: 0.35 }
            { id: "legsR", uri: "crab_legs_l", w: 100, x: 161, y: 72, px: 4, py: 20, anim: "rot", amp: 0.22, period: 0.35, po: 3.14 }
            { id: "body", uri: "crab_body", w: 220, x: 0, y: 0 }
        ] }
        star: { cx: 65, cy: 65, minX: 0, maxX: 130, scale: 0.55, speed: 9, bob: 0, flat: true, noFlip: true, sway: 0.05, swayPeriod: 16, crawl: 3.2, parts: [
            { id: "a0", uri: "seastar_arm", w: 50, x: 40, y: 3, px: 25, py: 62, rot: 0.0, anim: "rot", amp: 0.17, period: 3.2, po: 0.0, samp: [0, -0.16], sph: 1.57 }
            { id: "a1", uri: "seastar_arm", w: 50, x: 40, y: 3, px: 25, py: 62, rot: 1.2566, anim: "rot", amp: 0.17, period: 3.2, po: 1.2566, samp: [0, -0.16], sph: 1.57 }
            { id: "a2", uri: "seastar_arm", w: 50, x: 40, y: 3, px: 25, py: 62, rot: 2.5132, anim: "rot", amp: 0.17, period: 3.2, po: 2.5132, samp: [0, -0.16], sph: 1.57 }
            { id: "a3", uri: "seastar_arm", w: 50, x: 40, y: 3, px: 25, py: 62, rot: 3.7698, anim: "rot", amp: 0.17, period: 3.2, po: 3.7698, samp: [0, -0.16], sph: 1.57 }
            { id: "a4", uri: "seastar_arm", w: 50, x: 40, y: 3, px: 25, py: 62, rot: 5.0264, anim: "rot", amp: 0.17, period: 3.2, po: 5.0264, samp: [0, -0.16], sph: 1.57 }
            { id: "disc", uri: "seastar_disc", w: 60, x: 35, y: 35 }
        ] }
        diver: { cx: 100, cy: 66, minX: -104, maxX: 300, scale: 1.3, speed: 45, bob: 15, exhale: [292, 70], parts: [
            { id: "legF", uri: "diver_leg", w: 200, x: -104, y: 42, px: 196, py: 30, anim: "rot", amp: 0.18, period: 1.6, po: 3.14, dark: 0.7 }
            { id: "legN", uri: "diver_leg", w: 200, x: -96, y: 46, px: 196, py: 30, anim: "rot", amp: 0.18, period: 1.6 }
            { id: "body", uri: "diver_body", w: 300, x: 0, y: 0 }
        ] }
        school: { prey: true, cx: 240, cy: 100, minX: 0, maxX: 480, scale: 0.6, speed: 150, bob: 40, school: 14, parts: [] }
    }
end function
