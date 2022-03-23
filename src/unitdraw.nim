
template createUnitDraw() =
  const 
    shadowOffset = vec2(0.3f)
    shadowColor = rgba(0f, 0f, 0f, 0.4f)

  template getScl(base = 0.175f): Vec2 = vec2(base) + vec2(0.12f) * (1f - splashTime).pow(10f)
  template hoverOffset(scl = 0.65f, offset = 0f): Vec2 = vec2(0f, (fau.time + offset).sin(scl, 0.14f) - 0.14f)

  proc drawShadowed(patch: Patch, pos: Vec2, scl: Vec2) =
    patch.draw(pos - shadowOffset, scl = scl, color = shadowColor)
    patch.draw(pos, scl = scl)

  unitBoulder.draw = (proc(unit: Unit, basePos: Vec2) =
    let 
      scl = getScl(0.165f)
      pos = basePos
    
    patSpin(%"52525c", %"393843")

    let grad = %"393843"

    patGradient(grad, grad)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)
    unit.getTexture.draw(pos, scl = scl)
  )

  unitAlpha.draw = (proc(unit: Unit, basePos: Vec2) =
    patStripes(%"b25840", %"c07659")

    patGradient(colorAccent, colorAccent)

    fillPoly(basePos, 3, 3.5f, color = colorAccent, rotation = -90f.rad)
    poly(basePos, 3, 5.5f, stroke = 1f, color = colorAccent, rotation = -90f.rad)

    patLines(colorAccent, seed = 4)

    let 
      scl = getScl(0.165f)
      pos = basePos - vec2(0f, 0.5f) + hoverOffset() * 0.5f

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patSquares(colorAccent, time = fau.time, amount = 80, seed = 2)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitMono.draw = (proc(unit: Unit, basePos: Vec2) =
    let heal = %"84f490"

    patStripes(%"235e62", %"3a8a72")
    patGradient(%"3a8a72")
    patVertGradient(heal)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)

    patLines(heal)

    let 
      scl = getScl(0.175f)
      pos = basePos + hoverOffset()

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(heal, time = fau.time, amount = 100)

    unit.getTexture.draw(pos, scl = scl)

    drawBloom:
      unit.getTexture("-glow").draw(pos, scl = scl, mixcolor = rgba(1f, 1f, 1f, fau.time.sin(0.5f, 0.2f).abs))
  )

  unitOct.draw = (proc(unit: Unit, basePos: Vec2) =
    let heal = %"84f490"

    patStripes(%"235e62", %"3a8a72")
    patGradient(%"3a8a72")
    patVertGradient(heal)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)

    patLines(heal)

    let 
      scl = getScl(0.155f)
      pos = basePos + hoverOffset() + vec2(0f, 0.9f)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(heal, time = fau.time, amount = 120)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitOxynoe.draw = (proc(unit: Unit, basePos: Vec2) =
    let 
      heal = %"84f490"
      energy = %"c7ffb7"

    patStripes(%"235e62", %"3a8a72")
    patVertGradient(energy)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)

    patSpikes(basePos, heal, amount = 12)
    patSpikes(basePos, heal, amount = 24, offset = 13f, len = 3f)#, angleOffset = 360f.rad / 24)

    let 
      scl = getScl(0.175f)
      pos = basePos

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloomi(2f):
      patFlame(heal, energy, time = fau.time, amount = 300)

    unit.getTexture.draw(pos, scl = scl)

    drawBloomi(fau.time.absin(0.6f, 0.9f) + 0.2f):
      unit.getTexture("-flame").draw(basePos, scl = scl)
  )

  unitCrawler.draw = (proc(unit: Unit, pos: Vec2) =
    let 
      col1 = %"665c9f"
      col2 = %"bf92f8"
      light = %"edadff"

    patSpin(col1, col2, 20)

    patVertGradient(col1)

    patSpikes(pos, light, amount = 12)

    patVertGradient(col1.withA(0.6f), col1.withA(0f).mix(colorClear, 0.2f))

    fillPoly(pos, 4, 3f, color = light)
    poly(pos, 4, 5f, stroke = 1f, color = light)

    let scl = getScl(0.175f)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(light, time = fau.time, amount = 100, seed = 7)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitQuad.draw = (proc(unit: Unit, basePos: Vec2) =
    let
      heal = %"84f490"
      energy = %"c7ffb7"

    patSpin(%"235e62", %"3a8a72", blades = 16)

    patLines(heal, seed = 4)
    patVertGradient(energy)

    fillPoly(basePos, 4, 2.5f, color = heal)
    poly(basePos, 4, 4.5f, stroke = 1f, color = heal)

    patTriSquare(basePos, heal, 5.5f, 2f)

    let 
      scl = getScl(0.164f)
      pos = basePos - vec2(0.1f, 0.4f)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patFallSquares(heal, energy, time = fau.time, amount = 130)

    unit.getTexture.draw(pos, scl = scl)

    drawBloomi(1.5f + fau.time.sin(0.7f, 1f) + 0.5f):
      unit.getTexture("-energy").draw(pos, scl = scl)
    
    drawBuffer(sysDraw.bloom.buffer)
    unit.getTexture("-eyes").draw(pos, scl = scl)
    drawBufferScreen()
    sysDraw.bloom.blit(params = meshParams(blend = blendAdditive), intensity = (1f + fau.time.sin(0.7f, 1.5f)), threshold = 0f)
  )

  unitZenith.draw = (proc(unit: Unit, basePos: Vec2) =
    let
      col1 = %"c45b4d"
      col2 = %"ffa664"
      missilec = %"d06b53"

    #patStripes(col1, col2)
    patShapeBack(col1, col2)

    patVertGradient(col2)

    patLines(colorAccent, seed = 4)

    patVertGradient(col2.withA(0.7f), col2.withA(0f))

    fillPoly(basePos, 3, 3.5f, color = colorAccent, rotation = -90f.rad)
    poly(basePos, 3, 6f, stroke = 1f, color = colorAccent, rotation = -90f.rad)

    patTriSquare(basePos, colorAccent, amount = 3, len = 6f, offset = -30f.rad)

    let 
      scl = getScl(0.165f)
      pos = basePos - vec2(0f, 0.5f) + hoverOffset()

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patMissiles(missilec, time = fau.time, amount = 80, seed = 2)
      #patSquares(colorAccent, time = fau.time, amount = 80, seed = 2)

    unit.getTexture.draw(pos, scl = scl)

    unit.getTexture("-wowitos").drawShadowed(basePos + hoverOffset(0.6f, 1f) * 1.5f, scl)
    unit.getTexture("-controller").drawShadowed(basePos + hoverOffset(0.6f, 3f) * 1.4f, scl)
  )

  unitSei.draw = (proc(unit: Unit, basePos: Vec2) =
    let
      col1 = %"ffa664"
      col2 = %"ffcb82"
      missilec = %"d06b53"

    patStripes(col1, col2, angle = 45f.rad)

    patVertGradient(missilec)

    patLines(colorAccent, angle = -45f.rad)

    fillPoly(basePos, 4, 3f, color = colorAccent)
    poly(basePos, 4, 5f, stroke = 1f, color = colorAccent)

    patTriSquare(basePos, colorAccent, amount = 4, len = 6f)

    let 
      scl = getScl(0.175f)
      pos = basePos + hoverOffset()

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(missilec, time = fau.time, amount = 100)

    unit.getTexture.draw(pos, scl = scl)

    drawBloomi(fau.time.absin(0.6f, 0.9f) + 0.2f):
      unit.getTexture("-missiles").draw(basePos + hoverOffset(offset = 3f), scl = scl)
  )
  