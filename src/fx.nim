defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 13f.px):
      draw(smokeFrames[(fin.pow(2f) * smokeFrames.len).int.min(smokeFrames.high)], pos, color = %"a6a7b6")
  
  charSwitch(lifetime = 1f):
    particlesLife(e.id, 13, e.pos, e.fin + 0.2f, 20f.px):
      draw(smokeFrames[(fin.pow(2f) * smokeFrames.len).int.min(smokeFrames.high)], pos, color = colorAccent, z = 3000f)
  
  explode(lifetime = 0.4f):
    draw(explodeFrames[(e.fin * explodeFrames.len).int.min(explodeFrames.high)], e.pos, color = (%"ffb954").mix(%"d86a4e", e.fin))

  explodeHeal(lifetime = 0.4f):
    draw(explodeFrames[(e.fin * explodeFrames.len).int.min(explodeFrames.high)], e.pos, color = colorWhite.mix(colorHeal, e.fin.powout(2f)))

  walkWave:
    poly(e.pos, 4, e.fin.powout(6f) * 1f + 4f.px, stroke = 5f.px, color = colorWhite.withA(e.fout * 0.8f), rotation = 45f.rad)
  
  songShow(lifetime = 4f):
    if state.map != nil:
      defaultFont.draw("Music: " & state.map.songName, fau.cam.view - rect(vec2(0f, 0.8f + e.fin.pow(7f) + (when isMobile: 1.5f else: 0f)), vec2(0, 0f)), color = colorUi.withA(e.fout.powout(6f)), align = daTopLeft)
  
  tutorial(lifetime = 9f):
    let 
      offset = rect(vec2(0f, 0.8f + e.fin.pow(7f) + 1f), vec2(0, 0f))
      col = colorUi.withA(e.fout.powout(6f))
    
    defaultFont.draw(when isMobile: "[ SWIPE in a direction to move]\nyou can only move to the beat" else: "[ WASD or arrow keys to move]\nyou can only move to the beat", fau.cam.view - offset, color = col)

  strikeWave:
    #TODO looks bad
    #(%"bc8cff")
    let col = (%"c69eff").mix(colorAccent, e.fout.pow(4f)).withA(e.fout.pow(1.4f) * 0.9f)
    draw(patch(&"wave{e.rotation.int}"), e.pos, color = col)

    #let size = (4f - e.rotation)
    #poly(e.pos, 4, size * 5f.px + 4f.px, stroke = 5f.px, color = col, rotation = 45f.rad)
    #spikes(e.pos, 8, size * 5f.px + 10f.px, 4f.px, stroke = 3f.px, color = col)
  
  hit(lifetime = 0.9f):
    particlesLife(e.id, 10, e.pos, e.fin, 19f.px):
      draw(hitFrames[(fin.pow(2f) * hitFrames.len).int.min(hitFrames.high)], pos, color = colorWhite, z = 3000f)
      #fillPoly(pos + vec2(0f, 2f.px), 4, (2.5f * fout.powout(3f)).px, color = colorWhite, z = 3000f)
  
  laserShoot(lifetime = 0.6f):
    particlesLife(e.id, 14, e.pos, e.fin.powout(2f), 25f.px):
      fillPoly(pos, 4, (3f * fout.powout(3f) + 1f).px, rotation = 45f.rad, color = colorWhite, z = 3002f)

  destroy(lifetime = 0.7f):
    particlesLife(e.id, 12, e.pos, e.fin + 0.1f, 19f.px):
      draw(smokeFrames[(fin.pow(1.5f) * smokeFrames.len).int.min(smokeFrames.high)], pos, color = (%"ffa747").mix(%"d86a4e", e.fin))
  
  warn:
    poly(e.pos, 4, e.fout.pow(2f) * 0.6f + 0.5f, stroke = 4f.px * e.fout + 2f.px, color = colorWhite, rotation = 45f.rad)
    draw(fau.white, e.pos, size = vec2(16f.px), color = colorWhite.withA(e.fin))
  
  laserWarn:
    for i in signs():
      let stroke = 4f.px * e.fout + 1f.px
      lineAngleCenter(e.pos + vec2(0, (15f - 9f * e.fin.powout(2f)) * i.px).rotate(e.rotation), e.rotation, 1f - stroke, stroke = stroke)
    draw(fau.white, e.pos, size = vec2(1f, 12f.px), rotation = e.rotation, color = colorWhite.withA(e.fin))
  
  lancerAppear:
    draw("lancer2".patch, e.pos, rotation = e.rotation - 90f.rad, scl = vec2(state.moveBeat * 0.16f + min(e.fin.powout(3f), e.fout.powout(20f))), z = 3001f)
  
  warnBullet:
    #poly(e.pos, 4, e.fout.pow(2f) * 0.6f + 0.5f, stroke = 4f.px * e.fout + 2f.px, color = colorWhite, rotation = 45f.rad)
    draw("bullet".patch, e.pos, rotation = e.rotation, size = vec2(16f.px), mixColor = colorWhite, color = colorWhite.withA(e.fin))
  
  fail:
    draw("fail".patch, e.pos, color = colorWhite.withA(e.fout), scl = vec2(1f) + e.fout.pow(4f) * 0.6f)