
import core, vars

template createUnits*() =
  const 
    shadowOffset = vec2(0.3f)
    shadowColor = rgba(0f, 0f, 0f, 0.4f)

  template getScl(base = 0.175f): Vec2 = (vec2(base) + vec2(0.12f) * (1f - splashTime).pow(10f)) * fau.cam.size.y / 17f
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

    patVertGradient(grad)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)
    unit.getTexture.draw(pos, scl = scl)
  )

  unitAlpha.draw = (proc(unit: Unit, basePos: Vec2) =
    let light = %"b25840"
    patStripes(%"b25840", %"c07659")

    patVertGradient(colorAccent)

    fillPoly(basePos, 3, 3.5f, color = colorAccent, rotation = -90f.rad)
    poly(basePos, 3, 5.5f, stroke = 1f, color = colorAccent, rotation = -90f.rad)

    patVertGradient((%"c07659").withA(0.35f), (%"c07659").withA(0f))

    patLines(colorAccent, seed = 4)

    patVertGradient(light.withA(0.4f), light.withA(0f))

    let 
      scl = getScl(0.165f)
      pos = basePos - vec2(0f, 0.5f) + hoverOffset() * 0.5f

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patSquares(colorAccent, time = fau.time, amount = 80, seed = 2)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitMono.draw = (proc(unit: Unit, basePos: Vec2) =
    let 
      heal = %"84f490"
      col1 = %"235e62"
      col2 = %"3a8a72"

    patStripes(col1, col2)
    patGradient(col2)
    patVertGradient(heal)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)
    patLines(heal)

    patVertGradient(col2.withA(0.6f), col2.withA(0f))

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
    let 
      heal = %"84f490"
      stripe1 = %"235e62"
      stripe2 = %"3a8a72"

    patStripes(stripe1, stripe2)

    patLines(heal, seed = 8)

    patVertGradient(heal)

    fillPoly(basePos, 8, 3f, color = heal)
    poly(basePos, 8, 5f, stroke = 1f, color = heal)

    patSpikes(basePos, heal, amount = 8)
    patTriSquare(basePos, heal, 7f, 1.5f, amount = 8, offset = 45f.rad / 2f)

    patVertGradient(stripe2.withA(0.4f), stripe2.withA(0f))

    let 
      scl = getScl(0.155f)
      pos = basePos + hoverOffset() + vec2(0f, 0.9f)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patCircles(heal, time = fau.time, amount = 130, seed = 5)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitOxynoe.draw = (proc(unit: Unit, basePos: Vec2) =
    let 
      stripe1 = %"235e62"
      stripe2 = %"3a8a72"
      heal = %"84f490"
      energy = %"c7ffb7"

    patStripes(stripe1, stripe2)

    patVertGradient(energy)

    fillPoly(basePos, 4, 3f, color = heal)
    poly(basePos, 4, 5f, stroke = 1f, color = heal)

    patSpikes(basePos, heal, amount = 12)
    patSpikes(basePos, heal, amount = 24, offset = 13f, len = 3f, angleOffset = 360f.rad / 24 / 2f)

    patVertGradient(stripe2.withA(0.5f), stripe2.withA(0f))

    let 
      scl = getScl(0.171f)
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

    fillPoly(pos, 3, 3f, color = light, rotation = -90f.rad)
    poly(pos, 3, 5f, stroke = 1f, color = light, rotation = -90f.rad)

    patVertGradient(col1.withA(0.7f), col1.withA(0f).mix(colorClear, 0.2f))

    let scl = getScl(0.165f)

    unit.getTexture.draw(pos - shadowOffset, scl = scl, color = shadowColor)

    drawBloom:
      patRadTris(light, time = fau.time, amount = 100, seed = 7)

    unit.getTexture.draw(pos, scl = scl)
  )

  unitQuad.draw = (proc(unit: Unit, basePos: Vec2) =
    let
      heal = %"84f490"
      energy = %"c7ffb7"
      col1 = %"235e62"
      col2 = %"3a8a72"

    patSpin(col1, col2, blades = 16)

    patRadLines(heal, seed = 4, amount = 70)
    patVertGradient(energy)

    fillPoly(basePos, 4, 2.5f, color = heal)
    poly(basePos, 4, 4.5f, stroke = 1f, color = heal)

    patTriSquare(basePos, heal, 5.5f, 2f)

    patVertGradient(col2.withA(0.4f), col2.withA(0f))

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

    fillPoly(basePos, 3, 3.5f, color = colorAccent, rotation = -90f.rad)
    poly(basePos, 3, 6f, stroke = 1f, color = colorAccent, rotation = -90f.rad)

    patTriSquare(basePos, colorAccent, amount = 3, len = 6f, offset = -30f.rad)

    patVertGradient(col2.withA(0.7f), col2.withA(0f))

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

    patLines(colorAccent, angle = -45f.rad, seed = 13)

    fillPoly(basePos, 4, 3f, color = colorAccent)
    poly(basePos, 4, 5f, stroke = 1f, color = colorAccent)

    patTriSquare(basePos, colorAccent, amount = 4, len = 6f)

    patVertGradient(missilec.withA(0.5f), missilec.withA(0f))

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

  unitNothing.draw = (proc(unit: Unit, basePos: Vec2) =
    patSpin(%"23232c", %"49474d")
    patVertGradient(colorBlack)
  )
  
  unitAlpha.abilityProc = proc(entity: EntityRef, moves: int) =
    if moves mod 10 == 0:
      makeWall(entity.fetch(GridPos).vec - entity.fetch(Input).lastMove, health = 3)

  unitMono.abilityProc = proc(entity: EntityRef, moves: int) =
    if moves mod 4 == 0:
      addPoints(1)

  unitOct.abilityProc = proc(entity: EntityRef, moves: int) =
    var input = entity.fetch(Input)
    if input.shielded:
      input.shieldCharge = 0
    else:
      input.shieldCharge.inc

      if input.shieldCharge >= 30:
        input.shielded = true
        input.shieldCharge = 0
  
  unitCrawler.abilityProc = proc(entity: EntityRef, moves: int) =
    let pos = entity.fetch(GridPos).vec
    if moves mod 4 == 0:
      for dir in d4mid():
        effectExplode((pos + dir).vec2)
        damageBlocks(pos + dir)
  
  unitQuad.abilityProc = proc(entity: EntityRef, moves: int) =
    let pos = entity.fetch(GridPos).vec
    if moves mod 6 == 0:
      for dir in d8mid():
        effectExplodeHeal((pos + dir).vec2)
        damageBlocks(pos + dir)
  
  unitOxynoe.abilityProc = proc(entity: EntityRef, moves: int) =
    let pos = entity.fetch(GridPos).vec
    const sides = [vec2i(1, 0), vec2i(0, 1)]
    const signs = [-1, 0, 1]
    
    if moves mod 2 == 0:
      for i in signs:
        let target = sides[(moves div 2) mod 2] * i + pos
        effectExplodeHeal(target.vec2)
        damageBlocks(target)
  
  unitZenith.abilityProc = proc(entity: EntityRef, moves: int) =
    let
      pos = entity.fetch(GridPos).vec
      dir = entity.fetch(Input).lastMove
    if moves mod 4 == 0:
      for i in 0..<4:
        let target = pos + dir * i
        effectExplode(target.vec2)
        damageBlocks(target)
  
  unitSei.abilityProc = proc(entity: EntityRef, moves: int) =
    let pos = entity.fetch(GridPos).vec
    if moves mod 4 == 0:
      effectExplode(pos.vec2)
      damageBlocks(pos)
      for dir in d4edge():
        for i in 1..2:
          effectExplode((pos + dir * i).vec2)
          damageBlocks(pos + dir * i)