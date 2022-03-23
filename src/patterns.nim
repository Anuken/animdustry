proc patFft() =
  let 
    w = 20.px
    radius = 90f.px
    length = 8f
  
  for i in 0..<fftSize:
    let rot = i / fftSize.float32 * pi2
    draw(fau.white, vec2l(rot, radius), size = vec2(fftValues[i].px * length, w), rotation = rot, align = daLeft, origin = vec2(0f, w / 2f), color = colorPink.mix(colorWhite, 0.5f))

proc patTiles() =
  for x in -mapSize..mapSize:
    for y in -mapSize..mapSize:
      let 
        absed = ((x + mapSize) + (y + mapSize) + state.turn).mod 5
        strength = (absed == 0).float32 * state.moveBeat
      draw("tile".patchConst, vec2(x, y), color = colorWhite.mix(colorBlue, strength).withA(0.4f), scl = vec2(1f - 0.11f * state.moveBeat))

proc patTilesFft() =
  for x in -mapSize..mapSize:
    for y in -mapSize..mapSize:
      let 
        scaled = (y + mapSize) / (mapSize * 2 + 1)
        val = x + mapSize
        strength = (scaled < fftValues[val] / 13f).float32
      draw("tile".patchConst, vec2(x, y), color = colorWhite.mix(colorPink, strength).withA(0.4f), scl = vec2(1f - 0.11f * state.moveBeat))

proc patTilesSquare(col = colorWhite, col2 = colorBlue) =
  for x in -mapSize..mapSize:
    for y in -mapSize..mapSize:
      let 
        absed = (x.abs + y.abs - state.turn).emod(5)
        strength = (absed == 0).float32 * state.moveBeat
      draw("tile".patchConst, vec2(x, y), color = col.mix(col2, strength).withA(0.4f), scl = vec2(1f - 0.11f * state.moveBeat))

proc patBackground(col: Color) =
  draw(fau.white, fau.cam.pos, size = fau.cam.size, color = col)

#moving stripes
proc patStripes(col1 = colorPink, col2 = colorPink.mix(colorWhite, 0.2f)) =
  
  let 
    amount = 20
    swidth = 70f.px
    ang = 135f.rad
  for i in 0..<amount:
    let
      frac = (i + state.turn + ((1f - state.moveBeat).powout(8f))).mod(amount) / amount - 0.5f
      pos = vec2l(ang, swidth) * (frac * amount)
    draw(fau.white, pos, size = vec2(swidth, 1200f.px), rotation = ang, color = col1.mix(col2, (i.float32 mod 2f)))

proc patBeatSquare(col = colorPink.mix(colorWhite, 0.7f)) =
  poly(vec2(), 4, (45f + 15f * (state.turn mod 4).float32).px, 0f.rad, stroke = 10f.px, color = colorPink.mix(colorWhite, 0.7f).withA(state.moveBeat))

proc patBeatAlt(col: Color) =
  poly(vec2(), 4, (45f + 15f * (1 + state.turn mod 2).float32).px, 0f.rad, stroke = 10f.px, color = col.withA(state.moveBeat))

proc patFadeShapes(col: Color) =
  const 
    fadeSides = 4
    fadeCount = 10
    fscl = 0.5f
  
  proc drawFade(index: float32) =
    let rad = index * 100f.px
    poly(vec2(), fadeSides, rad, stroke = min(30f.px, rad * 1.5f), rotation = index * 10f.rad, color = col)

  for i in 0..<fadeCount:
    drawFade((i - (state.turn + (1f - state.moveBeat).powout(6f)) * fscl).emod(fadeCount))

proc patRain() =
  let 
    parts = 70
    partRange = 13f
    move = vec2(-0.5f, -0.5f)
    col = colorPink.mix(colorWhite, 0.4f)
    size = (5f + state.moveBeat.pow(2f) * 4f).px
  
  var r = initRand(1)
  
  for i in 0..<parts:
    var pos = vec2(r.range(partRange), r.range(partRange))

    pos += move * (state.turn + (1f - state.moveBeat).powout(30f))
    pos = (pos + partRange).emod(vec2(partRange * 2)) - partRange

    fillPoly(pos, 4, size, color = col)
    fillPoly(pos - move*0.5f, 4, size/2f, color = col)
    fillPoly(pos - move*0.9f, 4, size/4f, color = col)

proc patPetals() =
  let 
    parts = 50
    partRange = 18f
    move = vec2(-0.5f, -0.5f)
    col = colorPink.mix(colorWhite, 0.3f)
  
  var r = initRand(1)
  
  for i in 0..<parts:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(1f..2f)
      rot = r.range(180f.rad)
      rotSpeed = r.range(0.6f)
      scale = r.rand(0.4f..1f)

    pos += move * state.time * speed * 0.8f
    pos = fau.cam.viewport.wrap(pos, 2f)

    draw("petal".patchConst, pos, color = col, rotation = rot + state.time * rotSpeed, scl = scale.vec2)

proc patClouds(col = colorWhite) =
  var clouds {.global.}: array[4, Patch]

  once:
    for i in 1..4:
      clouds[i - 1] = ("cloud" & $i).patch

  let 
    count = 25
    partRange = 18f
    move = vec2(0.5f, 0f)
  
  var r = initRand(1)
  
  for i in 0..<count:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(1f..2f)
      scale = r.rand(0.4f..1f)
      sprite = clouds[r.rand(0..3)]

    pos += move * state.time * speed * 0.6f
    pos = fau.cam.viewport.wrap(pos, 80f.px)

    draw(sprite, pos, color = col, scl = scale.vec2)

proc patStars(col = colorWhite, flash = colorWhite) =
  var stars {.global.}: array[3, Patch]

  once:
    for i in 1..3:
      stars[i - 1] = ("star" & $i).patch

  let 
    count = 40
    partRange = 30f
  
  var r = initRand(1)
  
  for i in 0..<count:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let sprite = r.sample(stars)

    pos = fau.cam.viewport.wrap(pos, 4f.px)

    draw(sprite, pos.round(1f / tileSize), color = col.mix(flash, state.moveBeat))

proc patTris(col = colorWhite) =
  let 
    parts = 50
    partRange = 18f
    move = vec2(-0.3f, -0.5f)
  
  var r = initRand(1)
  
  for i in 0..<parts:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(1f..2f)
      rot = r.range(180f.rad)
      rotSpeed = 0f#r.range(0.6f)
      scale = r.rand(0.4f..1f)

    pos += move * state.time * speed * 0.4f
    pos = fau.cam.viewport.wrap(pos, 15f)

    fillPoly(pos, 3, scale * 14f.px, color = col, rotation = rot + state.time * rotSpeed)

proc patCircles(col = colorWhite, time = state.time, amount = 50) =
  let partRange = 18f 
  
  var r = initRand(1)
  
  for i in 0..<amount:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(1f..2f) * 0.2f
      rot = r.range(180f.rad)
      size = r.rand(2f..7f).px

    pos += vec2l(rot, speed) * time * speed
    pos = fau.cam.viewport.wrap(pos, 1f)

    fillCircle(pos, size, color = col)

proc patLines(col = colorWhite) =
  let 
    amount = 30
    spread = 14f
    stroke = 0.25f

  var r = initRand(1)
  
  for i in 0..<amount:
    let 
      ftime = fau.time + r.rand(2f)
      moveMag = r.rand(0.1f..0.3f)
      offset = vec2(ftime.sin(r.rand(0.6f..1f), moveMag), ftime.sin(r.rand(0.6f..1f), moveMag))
      pos = vec2(r.range(spread), r.range(spread)) + offset
      len = r.rand(2f..7f)
      
    lineAngleCenter(pos, 45f.rad, len, color = col, stroke = stroke)
    for i in signs():
      fillCircle(vec2l(45f.rad, len/2f + stroke/2f) * i.float32 + pos, stroke / 2f, color = col)

proc patGradient(col1 = colorClear, col2 = colorClear, col3 = colorClear, col4 = colorClear) =
  let r = fau.cam.viewport

  let uv = fau.white.uv
  drawVert(fau.white.texture, [
    vert2(r.botLeft, uv, col1, colorClear),
    vert2(r.botRight, uv, col2, colorClear),
    vert2(r.topRight, uv, col3, colorClear),
    vert2(r.topLeft, uv, col4, colorClear),
  ])