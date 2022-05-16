makeSystem("drawUI", []):
  fields:
    #epic hardcoded array size (it really doesn't get any better than this)
    levelFade: array[32, float32]
    unitFade: array[32, float32]
    hoverLevel: int
    glowPatch: Patch9
  init:
    sys.glowPatch = "glow".patch9
    sys.hoverLevel = -1

    #swipe controls
    when isMobile:
      var touchStart: array[32, Vec2]
      addFauListener proc(e: FauEvent) =
        case e.kind:
        of feTouch:
          if e.touchDown:
            touchStart[e.touchId] = e.touchPos
          else:
            let delta = e.touchPos - touchStart[e.touchId]
            #TODO sensitivity should depend on screen DPI or something
            if delta.len > 10f:
              let angle = delta.angle.deg
              
              let dir = 
                if angle >= 315f or angle <= 45f: 0
                elif angle in 45f..135f: 1
                elif angle in 135f..225f: 2
                else: 3

              if not settings.gamepad:
                mobilePad = d4f[dir]

        of feDrag:
          discard
        else: discard

  drawFlush()

  let 
    #bigger UI on mobile (smaller screen)
    uiScaling = when isMobile: 11f else: 17f
    camScl = min(fau.size.x, fau.size.y) / uiScaling
    rawScaling = 1f / camScl
    bottomMargin = fau.insets[2].abs * rawScaling
  
  fau.cam.use(fau.size / camScl)

  let screen = fau.cam.view

  if state.hitTime > 0:
    state.hitTime -= fau.delta / 0.4f
    state.hitTime = state.hitTime.max(0f)

  if state.healTime > 0:
    state.healTime -= fau.delta / 0.4f
    state.healTime = state.healTime.max(0f)

  if mode != gmPlaying and mode in ingameModes:
    let transitionTime = if mode == gmPaused: 0.5f else: 2.3f
    
    pauseTime += fau.delta / transitionTime
    pauseTime = min(pauseTime, 1f)
  else:
    pauseTime -= fau.delta / 0.2f
    pauseTime = pauseTime.max(0f)
  
  if pauseTime > 0:
    let midrad = 5f * pauseTime.powout(8)

    fillPoly(vec2(), 4, midrad, color = rgba(0f, 0f, 0f, 0.5f))
    poly(vec2(), 4, midrad, stroke = 4f.px, color = colorUi)

    let fontSize = fau.pixelScl * (1f + 2.5f * (1f - pauseTime.powout(5f)))
    var buttonPos = vec2(fau.cam.viewport.centerX, fau.cam.viewport.y).lerp(vec2(), pauseTime.powout(8f)) - vec2(0f, 0.5f)

    if mode == gmPaused:
      defaultFont.draw("[ paused ]", vec2(0f, 0.5f), scale = fontSize)
      buttonPos.y -= 1.3f
    elif mode == gmFinished:
      let hitText = if state.totalHits == 0: "\nno hits! (200% reward)" else: ""
      defaultFont.draw(&"[ level complete! ]\nfinal score: {state.points}{hitText}", vec2(0f, if state.totalHits == 0: 1.25f else: 0.75f), scale = fontSize, color = colorUi)

      draw("copper".patchConst, vec2(-0.6f, -0.4f), scl = vec2(fontSize / fau.pixelScl), mixcolor = colorWhite.withA(1f - pauseTime))
      defaultFont.draw(&" +{state.copperReceived}", vec2(0f, -0.35f), align = daLeft, scale = fontSize, color = %"d99d73")

      buttonPos.y -= 1.1f
    elif mode == gmDead:
      defaultFont.draw(&"[ level failed! ]", vec2(0f, 0.5f), scale = fontSize, color = colorHit)
      buttonPos.y -= 1.3f

    if mode != gmFinished and button(rectCenter(buttonPos + vec2(0f, 1.2f), 3f, 1f), "Retry"):
      let map = state.map
      capture map:
        safeTransition:
          playMap(map)
          mode = gmPlaying

    if button(rectCenter(buttonPos, 3f, 1f), "Menu"):
      safeTransition:
        reset()
        mode = gmMenu
        soundBack.play()
    
    #flash screen animation after winning
    if mode == gmFinished:
      draw(fau.white, fau.cam.pos, size = fau.cam.size, color = colorWhite.withA((1f - pauseTime).pow(4f)))
      poly(vec2(), 4, midrad + (1f - pauseTime).pow(4f) * 5f, stroke = (1f - pauseTime) * 9.px, color = colorWhite)
    elif mode == gmDead:
      draw(fau.white, fau.cam.pos, size = fau.cam.size, color = colorHit.withA((1f - pauseTime).pow(4f)))
      poly(vec2(), 4, midrad + (1f - pauseTime).pow(4f) * 5f, stroke = (1f - pauseTime) * 9.px, color = colorHit)

  if mode == gmIntro:
    drawPixel:
      patSpin(%"23232c", %"49474d")
      patVertGradient(colorBlack)

    introTime += fau.delta * 0.5f
    introTime = introTime.clamp
    draw("headphones".patchConst, vec2())

    titleFont.draw("SOUND REQUIRED", vec2(0f, 2.5f))
    defaultFont.draw("(yes, you really need it)", vec2(0f, -2f))

    defaultFont.draw(when isMobile: "[ tap to continue ]" else: "[ SPACE or ESC to continue ]", vec2(0f, -4f), color = colorUi.withA(fau.time.absin(0.5f, 1f)))

    if (keySpace.tapped or keyEscape.tapped) or (isMobile and keyMouseLeft.tapped):
      mode = gmMenu
      inIntro = true
      musicIntro.play()
      showSplashUnit(unitAlpha)

    draw(fau.white, vec2(), size = fau.cam.size, color = colorBlack.withA(1f - introTime))
  elif mode in ingameModes:
    #draw debug text
    when defined(debug):
      defaultFont.draw(&"{state.turn} | {state.beatStats} | {musicTime().int div 60}:{(musicTime().int mod 60):02} | {fau.fps} fps", fau.cam.view, align = daBot)
    
    #TODO
    if not defined(debug) and settings.showFps:
      defaultFont.draw(&"{fau.fps} fps", fau.cam.view, align = daBot)

    if scoreTime > 0:
      scoreTime -= fau.delta / 0.5f
    
    scoreTime = scoreTime.max(0f)

    if isDesktop:
      defaultFont.draw(&"[ {state.points:04} ]", fau.cam.view.grow(vec2(-4f.px, 0f)), align = daTopLeft, color = colorWhite.mix(if scorePositive: colorAccent else: colorHit, scoreTime.pow(3f)))
    elif mode != gmDead and mode != gmFinished:
      let buttonSize = 1.5f
      if button(rectCenter(screen.topLeft - vec2(-buttonSize/2f, buttonSize/2f), vec2(buttonSize)), icon = patch(if mode == gmPlaying: "pause" else: "play")):
        togglePause()

    let
      progSize = vec2(22f.px, 0f)
      progress = state.secs / state.map.soundLength
      healthPos = fau.cam.viewport.topRight - vec2(0.75f)

    draw("progress".patchConst, vec2(0f, fau.cam.size.y / 2f - 0.4f))
    draw("progress-tick".patchConst, vec2(0f, fau.cam.size.y / 2f - 0.4f) + progSize * (progress - 0.5f) * 2f, color = colorUiDark)

    draw("health".patchConst, healthPos, scl = vec2(1f + state.hitTime * 0.2f), color = colorUi.mix(colorHeal, state.healTime).mix(colorHit, state.hitTime))
    defaultFont.draw($health(), healthPos + vec2(0f, 1f.px), color = colorWhite.mix(colorHeal, state.healTime).mix(colorHit, state.hitTime))

    mobileUnitSwitch = -1

    let
      mouseWorld = fau.mouseWorld

    if sysInput.groups.len > 0:
      let player = sysInput.groups[0]

      for i, unit in save.units:
        let 
          pos = screen.xy + vec2(i.float32 * 0.8f, bottomMargin)
          current = player.unitDraw.unit == unit
          bounds = rect(pos, vec2(23f.px, 32f.px))
        draw(patch(&"unit-{unit.name}"), pos, align = daBotLeft, mixColor = if current: rgb(0.1f).withA(0.8f) else: colorClear, scl = vec2(0.75f))
        defaultFont.draw($(i + 1), rect(pos + vec2(4f.px, -2f.px), 1f.vec2), align = daBotLeft, color = if current: colorGray else: colorWhite)

        if keyMouseLeft.tapped and bounds.contains(mouseWorld):
          mobileUnitSwitch = i

    if isMobile and settings.gamepad:
      let 
        padSize = 1.75f
        padMargin = padSize * 1.75f
        padPos = if settings.gamepadLeft: screen.botLeft + vec2(padMargin, padMargin + bottomMargin) else: screen.botRight + vec2(-padMargin, padMargin + bottomMargin)
      
      for i, pos in d4f:
        let dp = padPos + pos * padSize
        if button(rectCenter(dp, vec2(padSize)), icon = "arrow".patchConst, rotation = i.float32 * 90f.rad, style = gamepadButtonStyle) and keyMouseLeft.tapped:
          mobilePad = pos

  elif splashUnit.isSome and splashRevealTime > 0f: #draw splash unit reveal animation
    splashRevealTime -= fau.delta / 3f

    let
      inv = 1f - splashRevealTime
      unit = splashUnit.get
      baseScl = inv.pow(14f)
      scl = vec2(0.17f) * baseScl
    
    if splashRevealTime < 0f:
      if unit == unitBoulder:
        soundVineBoom.play()
      elif unit == unitNothing:
        soundWind3.play()
      else:
        musicGet.play()
    
    draw(fau.white, vec2(), size = fau.cam.size, color = colorUiDark)
    patZoom(colorUi, inv.pow(2f), 10, sides = 4)

    drawBloom:
      patRadLines(col = colorUi, seed = 9, amount = 90, stroke = 0.2f, lenScl = 0.3f + inv.pow(4f) * 1.5f, posScl = 0.9f + inv.pow(5f) * 4.5f)
      patRadCircles(colorUi, fin = inv.pow(5f))

    patVertGradient(colorWhite)

    unit.getTexture.draw(vec2() - vec2(0.3f) * baseScl, scl = scl, color = rgba(0f, 0f, 0f, 0.4f))
    unit.getTexture.draw(vec2(), scl = scl, mixcolor = rgb(0.11f))

    #flash
    draw(fau.white, vec2(), size = fau.cam.size, color = rgba(1f, 1f, 1f, splashRevealTime.pow(2f)))

    #inv flash
    draw(fau.white, vec2(), size = fau.cam.size, color = rgba(1f, 1f, 1f, inv.pow(13f)))
  elif splashUnit.isSome: #draw splash unit
    #slower in intro for dramatic effect
    splashTime += fau.delta / (if inIntro: 11f else: 4f)
    splashTime = min(splashTime, 1f)

    let
      unit = splashUnit.get
      pos = vec2(0f, -5f.px)
      titleBounds = screen.grow(-0.4f)
      subtitleBounds = screen.grow(-2.2f)
      abilityW = screen.w / 4f
      abilityBounds = rect(screen.x + (screen.w - abilityW), screen.y, abilityW, screen.h).grow(-0.4f)

    if not unit.draw.isNil:
      unit.draw(unit, pos)
    
    #draw count
    defaultFont.draw("x" & $(1 + save.duplicates.getOrDefault(unit.name, 0)), screen.grow(vec2(-3f.px, 0f)), scale = 0.75f.px, color = colorAccent, align = daTopRight)
    
    #draw title and other UI
    titleFont.draw(
      unit.title, 
      titleBounds.xy, 
      bounds = titleBounds.wh, 
      scale = 1.5f.px,
      color = colorWhite,
      align = daTop,
      modifier = (proc(index: int, offset: var fmath.Vec2, color: var Color, draw: var bool) =
        offset.x += ((index + 0.5f) - unit.title.len/2f) * 15f.px * splashTime.powout(3f)
      )
    )

    defaultFont.draw(unit.subtitle, subtitleBounds, color = rgb(0.8f), align = daTop, scale = 0.75f.px)

    if unit.ability.len > 0:
      defaultFont.draw(unit.ability, abilityBounds, color = rgb(0.7f), align = daBotRight, scale = 0.75f.px)

    if not inIntro and (button(rectCenter(screen.x + 2f, screen.y + 1f + bottomMargin, 3f, 1f), "Back") or keyEscape.tapped):
      safeTransition:
        unit.clearTextures()
        splashUnit = none[Unit]()
        soundBack.play()
        splashTime = 0f
    
    #flash
    draw(fau.white, fau.cam.pos, size = fau.cam.size, color = rgba(1f, 1f, 1f, 1f - splashTime.powout(6f)))
  
    if splashTime >= 0.34f and inIntro:
      inIntro = false
      safeTransition:
        splashUnit = none[Unit]()
        mode = gmPlaying
        playMap(map1)
        effectTutorial(vec2())
  elif mode == gmMenu:
    #draw menu

    #draw menu background
    drawPixel:
      patStripes(%"accce3", %"57639a")

    let
      #height of stats box
      statsh = screen.h * 0.31f
      statsBounds = rect(screen.xy + vec2(0f, screen.h - statsh), screen.w, statsh)
      #bounds of level select buttons
      bounds = rect(screen.x, screen.y, screen.w, screen.h - statsh)
      sliced = bounds.w / allMaps.len
      mouse = fau.mouseWorld
      vertLen = 0.8f
      fadeCol = colorBlack.withA(0.7f)
      panMove = 1f
      unitSpace = 24f.px
    
    let buttonY = screen.top - 0.5f - 4f.px

    #gambling interface
    text(rectCenter(statsBounds.centerX + 4f, buttonY, 3f, 1f), &"{save.copper} / {copperForRoll}", align = daLeft, color = if save.copper >= copperForRoll: colorWhite else: %"ff4843")
    draw("copper".patchConst, vec2(statsBounds.centerX + 2f, buttonY))

    var bstyle = defaultButtonStyle
    bstyle.textUpColor = (%"ffda8c").mix(colorWhite, fau.time.sin(0.23f, 1f))

    var totalVisible = 0
    for unit in allUnits:
      if not unit.hidden or unit.unlocked:
        totalVisible.inc

    for i, unit in allUnits:
      let
        unlock = unit.unlocked
        x = statsBounds.centerX - (totalVisible - 1) * unitSpace/2f + i.float32 * unitSpace
        y = statsBounds.y + 6f.px
        hit = rect(x - unitSpace/2f, y, unitSpace, 32f.px)
        over = hit.contains(mouse) and unlock
      
      if unit.hidden and not unlock:
        continue
      
      unit.fade = unit.fade.lerp(over.float32, fau.delta * 20f)

      if over and not unit.wasOver:
        unit.jumping = true
        soundJump.play(pitch = calcPitch(i))
      
      unit.wasOver = over

      unit.clickTime -= fau.delta / 0.2f

      #TODO make it hold-able?
      if over and keyMouseRight.tapped:
        unit.clickTime = 1f
        if unit == unitBoulder:
          soundVineboom.play()
        else:
          soundPat.play(pitch = calcPitch((i mod 2)))
      
      if over and keyMouseLeft.tapped:
        showSplashUnit(unit)

        if unit == unitBoulder:
          soundVineBoom.play()
        else:
          musicView.play()

      if unit.jumping:
        unit.jump += fau.delta / 0.21f
        if unit.jump >= 1f:
          unit.jump = 0f
          unit.jumping = false

      let suffix = 
        if unit.clickTime > 0: "-hit"
        else: ""
      
      let 
        patch = patch(&"unit-{unit.name}{suffix}")
        jumpScl = sin(unit.jump * PI).float32
        click = unit.clickTime.clamp
      
      draw("shadow".patchConst, vec2(x, y - jumpScl * 3f.px), color = rgba(0f, 0f, 0f, 0.3f))

      draw(patch, vec2(x, y + jumpScl * 6f.px), 
        align = daBot, 
        mixColor = if unlock.not: rgb(0.26f) else: rgba(1f, 1f, 1f, unit.fade * 0.2f), 
        scl = vec2(1f + click * 0.1f, 1f - click * 0.1f),
        z = 1f
      )
    
    #TODO remove
    when defined(debug):
      save.copper = 10

    #must be after units so the unlocked unit does not appear right before rendering
    if button(rectCenter(statsBounds.centerX, buttonY, 3f, 1f), "Roll", disabled = save.copper < copperForRoll, style = bstyle):
      save.copper -= copperForRoll
      let unit = rollUnit()

      if unit.unobtainable.not:
        if save.units.find(unit) == -1:
          save.units.add unit
        else:
          let key = unit.name
          if not save.duplicates.hasKey(key):
            save.duplicates[key] = 1
          else:
            save.duplicates[key].inc
        sortUnits()

      saveGame()

      splashRevealTime = 0.5f
      musicReveal.play()
      showSplashUnit(unit)
    
    #outline around everything
    lineRect(statsBounds, stroke = 2f.px, color = colorUi, margin = 1f.px)

    let buttonSize = 1.5f

    if button(rectCenter(screen.topRight - vec2(buttonSize/2f), vec2(buttonSize)), icon = "info".patchConst):
      safeTransition:
        creditsPan = 0f
        mode = gmCredits
    
    if button(rectCenter(screen.topLeft - vec2(-buttonSize/2f, buttonSize/2f), vec2(buttonSize)), icon = "settings".patchConst):
      safeTransition:
        mode = gmSettings

    var anyHover = false

    #draw map select
    for i in countdown(allMaps.len - 1, 0):
      let 
        map = allMaps[i]
        unlocked = map.unlocked or defined(debug)
      assert map.preview != nil

      var
        offset = sys.levelFade[i]
        r = rect(bounds.x + sliced * i.float32, bounds.y, sliced, bounds.h)
      
      let
        hitRect = r
        over = hitRect.grow(-0.001f).contains(mouse)

      sys.levelFade[i] = offset.lerp(over.float32, fau.delta * 20f)

      if over:
        anyHover = true
        if sys.hoverLevel != i:
          soundSelect.play(pitch = calcPitch(i))
        sys.hoverLevel = i
      
      #only expands after bounds check to prevent weird input
      if i != allMaps.len - 1 and unlocked: #do not expand last map, no space for it
        r.w += offset * panMove

      var region = initPatch(map.preview.texture, (r.xy - screen.xy) / screen.wh, (r.topRight - screen.xy) / screen.wh)
      swap(region.v, region.v2)

      drawRect(region, r.x, r.y, r.w, r.h, mixColor = (if over: colorWhite.withA(0.2f) else: colorClear).mix(rgb(0.3f), unlocked.not.float32 * 0.7f), blend = blendDisabled)
      lineRect(r, stroke = 2f.px, color = map.fadeColor * (1.5f + offset * 0.5f), margin = 1f.px)

      let patchBounds = r

      if offset > 0.001f and unlocked:
        sys.glowPatch.draw(patchBounds.grow(16f.px), color = colorWhite.withA(offset * (0.8f + fau.time.sin(0.2f, 0.2f))), scale = fau.pixelScl, blend = blendAdditive, z = 2f)

      #map name
      text(r - rect(vec2(), 0f, offset * 8f.px) - rect(0f, 0f, 0f, 1f.px), if unlocked: &"Map {i + 1}" else: "[ locked ]", align = daTop, color = if unlocked: colorWhite else: rgb(0.5f))
      #high score, if applicable
      if unlocked:
        text(r - rect(vec2(), 0f, offset * 8f.px + 1f), if save.scores[i] > 0: &"High Score: {save.scores[i]}" else: "[ incomplete ]", align = daTop, color = (if save.scores[i] > 0: colorUi else: rgb(0.6f)).withA(offset))
      #song name
      if unlocked:
        text(r - rect(vec2(0f, -8f.px), 0f, offset * 8f.px), &"Music:\n{map.songName}", align = daBot, color = rgb(0.8f).mix(%"ffd565", offset.slope).withA(offset))

      #fading black shadow
      let uv = fau.white.uv
      drawVert(region.texture, [
        vert2(r.botRight, uv, fadeCol, colorClear),
        vert2(r.topRight, uv, fadeCol, colorClear),
        vert2(r.topRight + vec2(vertLen, 0f), uv, colorClear, colorClear),
        vert2(r.botRight + vec2(vertLen, 0f), uv, colorClear, colorClear),
      ])

      #click handling
      if over and keyMouseLeft.tapped and unlocked:
        capture map:
          safeTransition:
            playMap(map)
            mode = gmPlaying
    
    if not anyHover:
      sys.hoverLevel = -1

  elif mode == gmCredits:
    drawPixel:
      patStripes(%"332d4f", %"130d24")
      patVertGradient(%"130d24")
    
    patSkats()

    creditsPan -= fau.delta * 1.3f

    if keyMouseLeft.down or keySpace.down:
      creditsPan -= fau.delta * 3f

    let offset = creditsPan * 0.4f + screen.h - 1f

    defaultFont.draw(creditsText, fau.cam.view - rect(vec2(0f, offset), vec2()), scale = 0.75f.px, align = daTop)

    if button(rectCenter(screen.x + 2f, screen.y + 1f  + bottomMargin, 3f, 1f), "Back") or keyEscape.tapped:
      safeTransition:
        stop(musicReveal)
        soundBack.play()
        mode = gmMenu
  elif mode == gmSettings:
    patStripes(%"accce3", %"57639a")
    patVertGradient(%"57639a")
    
    let
      peekPos = vec2(screen.right - 3f, screen.y - 0.6f + bottomMargin)
      peekScl = 0.185f
      wallHeight = 313f * peekScl * fau.pixelScl
      outlineHeight = 11f * peekScl * fau.pixelScl
      peekCenter = vec2(11f, 365f) * peekScl * fau.pixelScl + peekPos
      peekDeltaRaw = ((fau.mouseWorld - peekCenter) / 2f).lim(1f) * 1f.px
      peekDelta = dizzyVec
      dizzy = dizzyTime > 0
      sampleRate = 60

      shadowRect = rect(vec2(screen.x, peekPos.y + wallHeight), vec2(screen.w, outlineHeight + 0.2f))
      shadowPatch = fau.white
      shadowCol = rgba(0f, 0f, 0f, 0.5f)
      uv = shadowPatch.uv
      mixcol = colorClear
      wallRect = rect(vec2(screen.x, screen.y), vec2(screen.w, wallHeight + peekPos.y - screen.y))
    
    #wall stuff
    drawVert(shadowPatch.texture, [
      vert2(shadowRect.xy, uv, shadowCol, mixcol),
      vert2(shadowRect.botRight, uv, shadowCol, mixcol),
      vert2(shadowRect.topRight, uv, mixcol, mixcol),
      vert2(shadowRect.topLeft, uv, mixcol, mixcol)
    ])

    fillRect(wallRect, color = %"b28768")
    fillRect(rect(vec2(screen.x, peekPos.y + wallHeight), vec2(screen.w, outlineHeight)), color = colorBlack)

    drawClip(wallRect)
    patStripes(%"accce3", %"57639a")
    drawClip()

    #eyes smoothly move to position
    dizzyVec.lerp(peekDeltaRaw, fau.delta * 25f)
    
    dizzyTime -= fau.delta
    dizzyCheckTime -= fau.delta * sampleRate.float32

    #sample angles for dizzy animation
    if dizzyCheckTime <= 0f:
      dizzySamples.addLast((fau.mouseWorld - peekCenter).angle)
      #ensure sample array size
      if dizzySamples.len > sampleRate * 2:
        discard dizzySamples.popFirst()
      dizzyCheckTime = 1f

      var 
        lastSign = 0
        totalRads = 0f
      
      for i in 0..<(dizzySamples.len - 1):
        let 
          curr = dizzySamples[i]
          next = dizzySamples[i + 1]
        
        let si = asign(curr, next)

        if lastSign == 0 or lastSign == si:
          #distance betwen two samples can't be too high, that usually implies a window switch or something
          totalRads += min(adist(curr, next), pi2 / 4f)
        else:
          #reset rotation, direction changes
          totalRads = 0f
        lastSign = si
      
      #check for a certain amount of revolutions and a minimum number of samples
      if totalRads >= pi2 * 2f and dizzyTime <= -0.5f and dizzySamples.len > 60:
        dizzyTime = 1f
        dizzySamples.clear()

    #TODO proper background w/ drop shadow
    if not dizzy:
      draw(unitAlpha.getTexture("-whites").toPatch, peekPos, align = daBot, scl = vec2(peekScl))

      for (sign, x, tex) in [(-1, -62f, "left"), (1, 44f, "right")]:
        let 
          pat = unitAlpha.getTexture("-eye-" & $tex).toPatch
          pos = peekPos + vec2(x, 372f) * peekScl * fau.pixelScl + vec2(peekDelta.x, (peekDelta.y * 0.6f).min(0.65f.px))
        
        draw(pat, pos, scl = vec2(peekScl))

    draw(unitAlpha.getTexture("peek").toPatch, peekPos, align = daBot, scl = vec2(peekScl))

    if dizzy:
      draw(unitAlpha.getTexture("-dizzy").toPatch, peekPos, align = daBot, scl = vec2(peekScl))
    
    titleFont.draw("S E T T I N G S", screen - rect(vec2(), vec2(0f, 4f.px)), align = daTop)

    let oldSettings = settings

    when isMobile:
      let padText = if settings.gamepad: "On" else: "Off"
      if button(rectCenter(vec2(0f, 0f), vec2(4f, 1f)), &"Gamepad: {padText}", toggled = settings.gamepad):
        settings.gamepad = settings.gamepad.not
      
      #TODO conflicts with character switching UI
      when false:
        let alignText = if settings.gamepadLeft: "Left" else: "Right"
        if button(rectCenter(vec2(0f, -2f), vec2(5f, 1f)), &"Pad Side: {alignText}", disabled = not settings.gamepad):
          settings.gamepadLeft = settings.gamepadLeft.not

    #TODO save settings on edit.

    slider(rectCenter(vec2(0f, 4f), vec2(9f, 1f)), 0f, 400f, settings.audioLatency, text = &"Audio Latency: {settings.audioLatency.int}ms")

    slider(rectCenter(vec2(0f, 2f), vec2(9f, 1f)), 0f, 1f, settings.globalVolume, text = &"Volume: {(settings.globalVolume * 100).int}%")
    
    #update every frame in case it changes (should have little to no overhead...)
    setGlobalVolume(settings.globalVolume)

    #only save setting when mutated
    if settings != oldSettings:
      saveSettings()
    
    #TODO
    if button(rectCenter(screen.x + 2f, screen.y + 1f  + bottomMargin, 3f, 1f), "Back") or keyEscape.tapped:
      safeTransition:
        soundBack.play()
        mode = gmMenu
    
    #only draw copper in debug mode to visualize the cursor for videos
    when defined(debug):
      draw("big-copper".patch, fau.mouseWorld, scl = vec2(peekScl * 1.5f))

  drawFlush()

  #handle fading
  if fadeTarget != nil:
    patFadeOut(fadeTime.powout(transitionPow))
    fadeTime += fau.delta / transitionTime
    if fadeTime >= 1f:
      fadeTarget()
      fadeTime = 1f
      fadeTarget = nil
  elif fadeTime > 0:
    patFadeIn(fadeTime.pow(transitionPow))
    fadeTime -= fau.delta / transitionTime