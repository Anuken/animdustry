


template createUnitDraw() =
  const scl = vec2(0.175f)

  unitMono.layers = @[
    (proc(unit: Unit, pos: Vec2) =
      patStripes(%"235e62", %"3a8a72")

      unit.getTexture("").draw(pos - vec2(0.3f), scl = scl, color = rgba(0f, 0f, 0f, 0.4f))
      unit.getTexture("").draw(pos, scl = scl)

      drawBuffer(sysDraw.bloom.buffer)

      unit.getTexture("-glow").draw(pos, scl = scl, mixcolor = rgba(1f, 1f, 1f, fau.time.sin(0.5f, 0.3f).abs))

      drawBufferScreen()
      sysDraw.bloom.blit(params = meshParams(blend = blendNormal))
    )
  ]