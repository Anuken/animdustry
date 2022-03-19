const fftSize = 50

var fftValues: array[fftSize, float32]

proc patFft() =
  let 
    fft = getFft()
    w = 20.px
    radius = 90f.px
    length = 8f
  
  for i in 0..<fftSize:
    fftValues[i] = lerp(fftValues[i], fft[i].pow(0.6f), 25f * fau.delta)

    let rot = i / fftSize.float32 * pi2
    draw(fau.white, vec2l(rot, radius), size = vec2(fftValues[i].px * length, w), rotation = rot, align = daLeft, origin = vec2(0f, w / 2f), color = colorPink.mix(colorWhite, 0.5f))

proc patBackground(col: Color) =
  draw(fau.white, fau.cam.pos, size = fau.cam.size, color = col)

#moving stripes
proc patStripes() =
  
  let 
    amount = 20
    swidth = 70f.px
    ang = 135f.rad
  for i in 0..<amount:
    let
      frac = (i + turn + ((1f - moveBeat).powout(8f))).mod(amount) / amount - 0.5f
      pos = vec2l(ang, swidth) * (frac * amount)
    draw(fau.white, pos, size = vec2(swidth, 1200f.px), rotation = ang, color = colorPink.mix(colorWhite, (i.float32 mod 2f) * 0.2f))

proc patBeatSquare() =
  poly(vec2(), 4, (45f + 15f * (turn mod 4).float32).px, 0f.rad, stroke = 10f.px, color = colorPink.mix(colorWhite, 0.7f).withA(moveBeat))

proc patFadeShapes(col: Color) =
  const 
    fadeSides = 4
    fadeCount = 10
    fadeCol = colorBlue
    fadeRadInc = 4f
    fscl = 0.5f
  
  proc drawFade(index: float32) =
    let rad = index * 100f.px
    poly(vec2(), fadeSides, rad, stroke = min(30f.px, rad * 1.5f), rotation = index * 10f.rad, color = col)

  var prevRad = 0f

  for i in 0..<fadeCount:
    drawFade((i - (turn + (1f - moveBeat).powout(6f)) * fscl).emod(fadeCount))

proc patRain() =
  let 
    parts = 70
    partRange = 13f
    move = vec2(-0.5f, -0.5f)
    col = colorPink.mix(colorWhite, 0.4f)
    size = (5f + beat().pow(2f) * 4f).px
  
  var r = initRand(1)
  
  for i in 0..<parts:
    var pos = vec2(r.range(partRange), r.range(partRange))

    pos += move * (turn + (1f - moveBeat).powout(30f))
    pos = (pos + partRange).emod(vec2(partRange * 2)) - partRange

    fillPoly(pos, 4, size, color = col)
    fillPoly(pos - move*0.5f, 4, size/2f, color = col)
    fillPoly(pos - move*0.9f, 4, size/4f, color = col)