
template createUnitDraw() =
  const 
    shadowOffset = vec2(0.3f)
    shadowColor = rgba(0f, 0f, 0f, 0.4f)

  template getScl(base = 0.175f): Vec2 = vec2(base) + vec2(0.12f) * (1f - splashTime).pow(10f)
  template hoverOffset(): Vec2 = vec2(0f, fau.time.sin(0.65f, 0.14f) - 0.14f)

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
    patGradient(heal, heal)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)

    patLines(heal)

    let 
      scl = getScl(0.175f)
      pos = basePos + hoverOffset()

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(%"84f490", time = fau.time, amount = 100)

    unit.getTexture.draw(pos, scl = scl)

    drawBloom:
      unit.getTexture("-glow").draw(pos, scl = scl, mixcolor = rgba(1f, 1f, 1f, fau.time.sin(0.5f, 0.2f).abs))
  )