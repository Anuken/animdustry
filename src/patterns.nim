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
proc patStripes(col1 = colorPink, col2 = colorPink.mix(colorWhite, 0.2f), angle = 135f.rad) =
  
  let 
    amount = 20
    swidth = 70f.px
  for i in 0..<amount:
    let
      frac = (i + state.turn + ((1f - state.moveBeat).powout(8f))).mod(amount) / amount - 0.5f
      pos = vec2l(angle, swidth) * (frac * amount)
    draw(fau.white, pos, size = vec2(swidth, 1200f.px), rotation = angle, color = col1.mix(col2, (i.float32 mod 2f)))

proc patBeatSquare(col = colorPink.mix(colorWhite, 0.7f)) =
  poly(vec2(), 4, (45f + 15f * (state.turn mod 4).float32).px, 0f.rad, stroke = 10f.px, color = colorPink.mix(colorWhite, 0.7f).withA(state.moveBeat))

proc patBeatAlt(col: Color) =
  poly(vec2(), 4, (45f + 15f * (1 + state.turn mod 2).float32).px, 0f.rad, stroke = 10f.px, color = col.withA(state.moveBeat))

proc patTriSquare(pos: Vec2, col: Color, len = 4f, rad = 2f, offset = 45f.rad, amount = 4, sides = 3, shapeOffset = 0f.rad) =
  for i in 0..<amount:
    fillPoly(vec2l(i * (360f.rad / amount) + offset, len) + pos, sides, rad, color = col, rotation = i * (360f.rad / amount) + offset + shapeOffset)

proc patSpin(col1, col2: Color, blades = 10) =
  let 
    len = max(fau.cam.size.x, fau.cam.size.y)
    space = 360f.rad / blades

  for i in 0..<blades:
    fillTri(
      vec2(),
      vec2l(i * space, len),
      vec2l((i + 1) * space, len),
      if i mod 2 == 0: col1 else: col2
    )

proc patShapeBack(col1, col2: Color, sides = 4, spacing = 2.5f, angle = 90f.rad) =
  let amount = (fau.cam.size.x.max(fau.cam.size.y) / spacing).int + 1

  fillPoly(vec2(), sides, spacing, color = col1, rotation = angle)
  for i in 1..amount:
    poly(vec2(), sides, (i + 0.5f) * spacing, rotation = angle, stroke = spacing, color = if (i and 1) == 0: col1 else: col2)

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

proc patCircles(col = colorWhite, time = state.time, amount = 50, seed = 1) =
  let partRange = 18f 
  
  var r = initRand(seed)
  
  for i in 0..<amount:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(0.8f..2f) * 0.2f
      rot = r.range(180f.rad)
      size = r.rand(2f..7f).px

    pos += vec2l(rot, speed) * time * speed
    pos = fau.cam.viewport.wrap(pos, 1f)

    fillCircle(pos, size, color = col)

proc patRadTris(col = colorWhite, time = state.time, amount = 50, seed = 1) =
  let partRange = 18f 
  
  var r = initRand(seed)
  
  for i in 0..<amount:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(0.8f..2f) * 0.2f
      rot = pos.angle
      size = r.rand(2f..7f).px * 2.1f

    pos += vec2l(rot, speed) * time * speed
    pos = fau.cam.viewport.wrap(pos, 1f)

    fillPoly(pos, 3, size, color = col, rotation = pos.angle)

proc patMissiles(col = colorWhite, time = state.time, amount = 50, seed = 1) =
  let partRange = 18f 
  
  var r = initRand(seed)
  
  for i in 0..<amount:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(0.9f..2f) * 1f
      sizeScl = 1f + (time + r.rand(0f..4f)).sin(0.5f, 0.2f)
      size = r.rand(4f..7f).px * sizeScl
      
    pos += vec2(speed) * time
    pos = fau.cam.viewport.wrap(pos, 3f)

    for index, scl in [1f, 0.75f, 0.5f, 0.25f]:
      fillCircle(pos - vec2l(45f.rad, index.float32 * 0.5f) * 1.1f, size * scl, color = col)

proc patFallSquares(col = colorWhite, col2 = colorWhite, time = state.time, amount = 50) =
  let partRange = fau.cam.size.x / 2f 
  
  var r = initRand(1)
  
  for i in 0..<amount:
    let
      view = fau.cam.viewport
      lifetime = r.rand(15f..34f)
      life = (r.rand(1f) + time / lifetime).mod 1f
      rot = r.range(180f.rad) + time * r.rand(0.8f..1.5f)
      size = r.rand(3f..9f).px * 1.25f
      pos = vec2(r.range(partRange), view.top + 1f - life * (view.h * 2f))

    draw(fau.white, pos, size = size.vec2, color = col.mix(col2, life), rotation = rot)

proc patFlame(col = colorWhite, col2 = colorWhite, time = state.time, amount = 80) =
  let partRange = fau.cam.size.x / 2f 
  
  var r = initRand(1)
  
  for i in 0..<amount:
    let
      view = fau.cam.viewport
      lifetime = r.rand(13f..24f)
      life = (r.rand(1f) + time / lifetime).mod 1f
      size = r.rand(5f..11f).px * 2.1f * (1f - life)
      smag = r.rand(0.5f)
      sscl = r.rand(0.8f..3f)
      pos = vec2(r.range(partRange) + time.sin(sscl, smag), view.y - 2f + life * (view.h + 4f))

    fillCircle(pos, size / 2f, color = col.mix(col2, life))

proc patSquares(col = colorWhite, time = state.time, amount = 50, seed = 2) =
  let partRange = 18f 
  
  var r = initRand(seed)
  
  for i in 0..<amount:
    var pos = vec2(r.range(partRange), r.range(partRange))
    let
      speed = r.rand(1f..2f) * 0.2f
      rot = r.range(180f.rad)
      pulseScl = r.rand(0.6f..0.9f)
      size = r.rand(2.3f..6f).px * (1f + time.sin(pulseScl, 0.2f))
      
    pos += vec2l(rot, speed) * time * speed
    pos = fau.cam.viewport.wrap(pos, 1f)

    draw(fau.white, pos, size = size.vec2 * 2f, color = col, rotation = 45f.rad)

proc roundLine(pos: Vec2, angle: float32, len: float32, color = colorWhite, stroke = 1f) =
  lineAngleCenter(pos, angle, len, color = color, stroke = stroke)
  for i in signs():
    fillCircle(vec2l(angle, len/2f + stroke/2f) * i.float32 + pos, stroke / 2f, color = color)

proc patLines(col = colorWhite, seed = 1, amount = 30, angle = 45f.rad) =
  let 
    spread = 13.5f
    stroke = 0.25f

  var r = initRand(seed)
  
  for i in 0..<amount:
    let 
      ftime = fau.time + r.rand(2f)
      moveMag = r.rand(0.1f..0.3f)
      offset = vec2(ftime.sin(r.rand(0.6f..1f), moveMag), ftime.sin(r.rand(0.6f..1f), moveMag))
      pos = vec2(r.range(spread), r.range(spread)) + offset
      len = r.rand(2f..7f)
    
    roundLine(pos, angle, len, col, stroke)

proc patRadLines(col = colorWhite, seed = 6, amount = 40, stroke = 0.25f, posScl = 1f, lenScl = 1f) =
  var r = initRand(seed)
  
  for i in 0..<amount:
    let 
      ftime = fau.time + r.rand(2f)
      moveMag = r.rand(0.1f..0.3f)
      offset = vec2(ftime.sin(r.rand(0.6f..1f), moveMag), ftime.sin(r.rand(0.6f..1f), moveMag))
      angle = r.rand(360f.rad)
      len = r.rand(2f..5f) * lenScl
      pos = vec2l(angle, len/2f + r.rand(2.5f..16f) * posScl) + offset
    
    roundLine(pos, angle, len, col, stroke)

proc patRadCircles(col = colorWhite, seed = 7, amount = 40, fin = 0.5f) =
  var r = initRand(seed)
  
  for i in 0..<amount:
    let 
      angle = r.rand(360f.rad)
      len = r.rand(6f..30f) * fin + r.rand(1f..3f)
      rad = r.rand(1.2f) * fin
      pos = vec2l(angle, len)
    
    fillCircle(pos, rad, color = col)

proc patSpikes(pos: Vec2, col = colorWhite, amount = 10, offset = 8f, len = 3f, angleOffset = 0f) =
  for i in 0..<amount:
    let angle = i.float32 / amount * 360f.rad + angleOffset
    roundLine(pos + vec2l(angle, offset), angle, len, col, 0.25f)

proc patGradient(col1 = colorClear, col2 = colorClear, col3 = colorClear, col4 = colorClear) =
  let r = fau.cam.viewport

  let uv = fau.white.uv
  drawVert(fau.white.texture, [
    vert2(r.botLeft, uv, col1, colorClear),
    vert2(r.botRight, uv, col2, colorClear),
    vert2(r.topRight, uv, col3, colorClear),
    vert2(r.topLeft, uv, col4, colorClear),
  ])

proc patVertGradient(col1 = colorClear, col2 = colorClear) =
  patGradient(col1, col1, col2, col2)

proc patZoom(col = colorWhite, offset = 0f, amount = 10, sides = 4) =
  for i in 0..<amount:
    let frac = (i / amount + offset).mod(1f)
    poly(vec2(), sides, 1f + frac.pow(1.3f) * 44f, stroke = frac * 5f, color = col)

proc patFadeOut(time: float32) =
  let 
    view = fau.cam.viewport
    shiftLen = view.w + view.h
    offset = vec2(shiftLen * time, 0f)
  
  fillQuad(
    view.topLeft + offset,
    view.topLeft - vec2(view.h) + offset,
    view.topLeft - vec2(view.h) - vec2(view.w, 0f) + offset,
    view.topLeft - vec2(view.h, 0f) - vec2(view.w, 0f) + offset,
    colorUi
  )

proc patFadeIn(time: float32) =
  let 
    view = fau.cam.viewport
    shiftLen = view.w + view.h
    offset = vec2(shiftLen * (1f - time), 0f)
  
  fillQuad(
    view.topRight + offset,
    view.botRight + offset,
    view.botLeft + offset - vec2(view.h, 0f),
    view.topLeft + offset,
    colorUi
  )