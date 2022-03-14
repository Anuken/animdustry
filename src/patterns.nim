

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
  poly(vec2(), 4, (45f + 15f * (musicState.beatCount mod 4).float32).px, 0f.rad, stroke = 10f.px, color = colorPink.mix(colorWhite, 0.7f).withA(beat()))

proc patFadeShapes() =
  const 
    fadeSides = 4
    fadeCount = 10
    fadeCol = colorBlue
    fadeRadInc = 4f
    fscl = 0.5f
  
  proc drawFade(index: float32) =
    let rad = index * 100f.px
    poly(vec2(), fadeSides, rad, stroke = min(30f.px, rad * 1.5f), rotation = index * 10f.rad, color = colorPink.mix(colorWhite, 0.2f))

  var prevRad = 0f

  for i in 0..<fadeCount:
    drawFade((i - (turn + (1f - moveBeat).powout(6f)) * fscl).emod(fadeCount))

    #[
    prevRad += (10 + i * 5f).px

    let
      stroke = i * 9f.px
    
    poly(vec2(), fadeSides, prevRad, stroke = stroke, rotation = fau.time * 0.5f + i * 10f.rad)

    prevRad += stroke*2f
    ]#


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