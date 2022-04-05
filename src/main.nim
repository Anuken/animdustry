#pack every compile
static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048 --outlineFolder=outlined/")

import ecs, fau/presets/[basic, effects], fau/g2/[font, ui, bloom], fau/assets
import std/[tables, sequtils, algorithm, macros, options, random, math, strformat]
import types, vars, saveio, patterns, maps, sugar, units

include components
include fx

onEcsBuilt:
  proc makeDelay(delay: int, callback: proc()) =
    discard newEntityWith(RunDelay(delay: delay, callback: callback))

  template runDelay(body: untyped) =
    makeDelay(0, proc() =
      body
    )

  template runDelayi(amount: int, body: untyped) =
    makeDelay(amount, proc() =
      body
    )

  proc makeBullet(pos: Vec2i, dir: Vec2i, tex = "bullet") =
    discard newEntityWith(DrawBullet(sprite: tex), Scaled(scl: 1f), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage())

  proc makeTimedBullet(pos: Vec2i, dir: Vec2i, tex = "bullet", life = 3) =
    discard newEntityWith(DrawBullet(sprite: tex), Scaled(scl: 1f), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage(), Lifetime(turns: life))

  proc makeConveyor(pos: Vec2i, dir: Vec2i, length = 2, tex = "conveyor") =
    discard newEntityWith(DrawSquish(sprite: tex), Scaled(scl: 1f), Destructible(), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage(), Snek(len: length))

  proc makeLaser(pos: Vec2i, dir: Vec2i) =
    discard newEntityWith(Scaled(scl: 1f), DrawLaser(dir: dir), Pos(), GridPos(vec: pos), Damage(), Lifetime(turns: 1))

  proc makeRouter(pos: Vec2i, length = 2, life = 2, diag = false, sprite = "router", alldir = false) =
    discard newEntityWith(DrawSpin(sprite: sprite), Scaled(scl: 1f), Destructible(), Pos(), GridPos(vec: pos), Damage(), SpawnConveyors(len: length, diagonal: diag, alldir: alldir), Lifetime(turns: life))

  proc makeSorter(pos: Vec2i, mdir: Vec2i, moveSpace = 2, spawnSpace = 2, length = 1) =
    discard newEntityWith(DrawSpin(sprite: "sorter"), Scaled(scl: 1f), Destructible(), Velocity(vec: mdir, space: moveSpace), Pos(), GridPos(vec: pos), Damage(), SpawnEvery(offset: 1, space: spawnSpace, spawn: SpawnConveyors(len: length, dir: -mdir)))

  proc makeTurret(pos: Vec2i, face: Vec2i, reload = 4, life = 8, tex = "duo") =
    discard newEntityWith(DrawBounce(sprite: tex, rotation: face.vec2.angle - 90f.rad), Scaled(scl: 1f), Destructible(), Pos(), GridPos(vec: pos), Turret(reload: reload, dir: face), Lifetime(turns: life))

  proc makeArc(pos: Vec2i, dir: Vec2i, tex = "arc", bounces = 1, life = 3) =
    discard newEntityWith(DrawBounce(sprite: tex, rotation: dir.vec2.angle), LeaveBullet(life: life), Velocity(vec: dir), Bounce(count: bounces), Scaled(scl: 1f), Destructible(), Pos(), GridPos(vec: pos))

  proc makeWall(pos: Vec2i, sprite = "wall", life = 10, health = 3) =
    discard newEntityWith(DrawBounce(sprite: sprite), Scaled(scl: 1f), Wall(health: health), Pos(), GridPos(vec: pos), Lifetime(turns: life))

  proc makeUnit(pos: Vec2i, aunit: Unit) =
    discard newEntityWith(Input(nextBeat: -1), Pos(), GridPos(vec: pos), UnitDraw(unit: aunit))

  proc reset() =
    sysAll.clear()
    sysRunDelay.clear()

    #stop old music
    if state.voice.int != 0:
      state.voice.stop()

    #make default map
    state = GameState(
      map: map1
    )
  
  proc playMap(next: Beatmap, offset = 0.0) =
    reset()

    #start with first unit
    makeUnit(vec2i(), if save.lastUnit != nil: save.lastUnit else: save.units[0])

    state.map = next
    state.voice = state.map.sound.play()
    if offset > 0.0:
      state.voice.seek(offset)
    
    effectSongShow(vec2())
  
  proc addPoints(amount = 1) =
    state.points += amount
    state.points = state.points.max(1)
    scoreTime = 1f
    scorePositive = amount >= 0

  proc damageBlocks(target: Vec2i) =
    let hitbox = rectCenter(target.vec2, vec2(0.99f))
    for item in sysDestructible.groups:
      if item.gridPos.vec == target or rectCenter(item.pos.vec, vec2(1f)).overlaps(hitbox):
        effectDestroy(item.pos.vec)
        if not item.entity.has(Deleting):
          item.entity.add(Deleting(time: 1f))

          #block destruction -> extra points
          addPoints(1)

template zlayer(entity: untyped): float32 = 1000f - entity.pos.vec.y

template transition(body: untyped) =
  fadeTime = 0f
  fadeTarget = proc() =
    body

template safeTransition(body: untyped) =
  if not fading():
    fadeTime = 0f
    fadeTarget = proc() =
      body

template drawPixel(body: untyped) =
  drawBuffer(sysDraw.buffer)
  body
  drawBufferScreen()
  sysDraw.buffer.blit()

template drawBloom(body: untyped) =
  drawBuffer(sysDraw.bloom.buffer)
  body
  drawBufferScreen()
  sysDraw.bloom.blit(params = meshParams(blend = blendNormal))

template drawBloomi(bloomIntensity: float32, body: untyped) =
  drawBuffer(sysDraw.bloom.buffer)
  body
  drawBufferScreen()
  sysDraw.bloom.blit(params = meshParams(blend = blendNormal), intensity = bloomIntensity)

proc showSplashUnit(unit: Unit) =
  splashUnit = unit.some
  splashTime = 0f

proc clearTextures*(unit: Unit) = unit.textures.clear()

proc getTexture*(unit: Unit, name: string = ""): Texture =
  ## Loads a unit texture from the textures/ folder. Result is cached. Crashes if the texture isn't found!
  if not unit.textures.hasKey(name):
    let tex = loadTextureAsset("textures/" & unit.name & name & ".png")
    tex.filter = tfLinear
    unit.textures[name] = tex
    return tex
  return unit.textures[name]

proc rollUnit*(): Unit =
  #very low chance, as it is annoying
  if chance(2f / 100f):
    return unitNothing

  #boulder has a much higher chance to be selected, because it's useless
  if chance(0.4f):
    return unitBoulder

  #not all units; alpha and boulder are excluded
  return sample([unitMono, unitOct, unitCrawler, unitZenith, unitQuad, unitOxynoe, unitSei])

proc fading(): bool = fadeTarget != nil

proc beatSpacing(): float = 1.0 / (state.map.bpm / 60.0)

proc musicTime(): float = state.secs

proc calcPitch(note: int): float32 =
  const indices = [0, 4, 7]
  let 
    octave = note.euclDiv 3
    index = note.euclMod 3
  let a = pow(2.0, 1.0 / 12.0)
  return pow(a, indices[index].float + octave.float * 12f).float32

proc highScore(map: Beatmap): int =
  let index = allMaps.find(map)
  return save.scores[index]

proc `highScore=`(map: Beatmap, value: int) =
  let index = allMaps.find(map)
  if save.scores[index] != value:
    save.scores[index] = value
    saveGame()

proc unlocked(map: Beatmap): bool =
  let index = allMaps.find(map)
  return index <= 0 or save.scores[index - 1] > 0 or save.scores[index] > 0

proc health(): int = 
  if state.map.isNil: 1 else: state.map.maxHits.max(1) - state.hits

proc unlocked(unit: Unit): bool =
  for u in save.units:
    if u == unit: return true

proc sortUnits =
  save.units.sort do (a, b: Unit) -> int:
    cmp(allUnits.find(a), allUnits.find(b))
  
  save.units = save.units.deduplicate(true)

makeSystem("core", []):
  init:
    fau.maxDelta = 100f
    #TODO apparently can be a disaster on windows? does the apparent play position actually depend on latency???
    #audioLatency = getAudioBufferSize() / getAudioSampleRate() - 10.0 / 1000.0

    echo &"Audio stats: {getAudioBufferSize()} buffer / {getAudioSampleRate()}hz; calculated latency: {getAudioBufferSize() / getAudioSampleRate() * 1000} ms"

    fau.pixelScl = 1f / tileSize
    uiFontScale = fau.pixelScl
    uiPatchScale = fau.pixelScl
    uiScale = fau.pixelScl

    defaultFont = loadFont("font.ttf", size = 16, outline = true)
    titleFont = loadFont("title.ttf", size = 16, outline = true)

    defaultButtonStyle = ButtonStyle(
      up: "button".patch9,
      overColor: colorWhite.withA(0.3f),
      downColor: colorWhite.withA(0.5f),
      #disabledColor: rgb(0.6f).withA(0.4f),
      textUpColor: colorWhite,
      textDisabledColor: rgb(0.6f)
    )

    #not fps based
    fau.targetFps = 0

    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()

    createMaps()
    allMaps = @[map1, map2, map3, map4, map5]

    createUnits()

    loadGame()

    #must have at least one unit as a default
    if save.units.len == 0:
      save.units.add unitAlpha
    
    sortUnits()

    if save.lastUnit == nil or save.lastUnit == unitBoulder:
      save.lastUnit = unitAlpha

    #resize scores to hold all maps
    if save.scores.len < allMaps.len:
      save.scores.setLen(allMaps.len)
    
    #play the intro once
    if not save.introDone:
      mode = gmIntro
      save.introDone = true
      saveGame()
  
  #All passed systems will be paused when game state is not playing
  macro makePaused(systems: varargs[untyped]): untyped =
    result = newStmtList()
    for sys in systems:
      result.add quote do:
        `sys`.paused = (mode != gmPlaying)

  #yeah this would probably work much better as a system group
  makePaused(
    sysUpdateMusic, sysDeleting, sysUpdateMap, sysPosLerp, sysInput, sysTimed, sysScaled, 
    sysLifetime, sysSnek, sysSpawnEvery, sysSpawnConveyors, sysTurretFollow, 
    sysTurretShoot, sysDamagePlayer, sysUpdateVelocity, sysKillOffscreen,
    sysUpdateBounce, sysLeaveBullet
  )

  if mode in {gmPlaying, gmPaused} and (keySpace.tapped or keyEscape.tapped):
    mode = if mode != gmPlaying: gmPlaying else: gmPaused
    if mode == gmPlaying:
      soundUnpause.play()
    else:
      soundPause.play()
  
  #trigger game over
  if mode == gmPlaying and health() <= 0:
    mode = gmDead
    soundDie.play()

  when defined(debug):
    if keyEscape.tapped:
      quitApp()

makeSystem("all", [Pos]): discard

makeSystem("destructible", [GridPos, Pos, Destructible]): discard

makeSystem("wall", [GridPos, Wall]):
  all:
    #this can't be part of the components as it causes concurrent modification issues
    
    if state.playerPos == item.gridPos.vec and not item.entity.has(Deleting):
      effectHit(item.gridPos.vec.vec2)
      item.entity.add(Deleting(time: 1f))

makeSystem("updateMusic", []):
  start:
    if state.voice.valid:
      state.voice.paused = sys.paused

  state.newTurn = false
  state.time += fau.delta

  if state.voice.valid and state.voice.playing:
    let beatSpace = beatSpacing()

    state.moveBeat -= fau.rawDelta / beatSpace
    state.moveBeat = max(state.moveBeat, 0f)
    
    let nextSecs = state.voice.streamPos - audioLatency + state.map.beatOffset

    if nextSecs == state.lastSecs:
      #beat did not change, move it forward manually to compensate for low "frame rate"
      state.secs += fau.rawDelta
    else:
      state.secs = nextSecs
    state.lastSecs = nextSecs

    let nextBeat = int(state.secs / beatSpace)

    state.newTurn = nextBeat != state.turn
    state.turn = nextBeat
    state.rawBeat = (1.0 - ((state.secs mod beatSpace) / beatSpace)).float32

    let fft = getFft()

    for i in 0..<fftSize:
      fftValues[i] = lerp(fftValues[i], fft[i].pow(0.6f), 25f * fau.delta)
    
    if state.newTurn:
      state.moveBeat = 1f
  elif state.voice.valid.not:
    mode = gmFinished
    soundWin.play()

    #calculate copper received and add it to inventory
    let 
      maxCopper = if state.map.copperAmount == 0: defaultMapReward else: state.map.copperAmount
      #perfect amount of copper received if the player always moved and never missed / got hit
      perfectPoints = state.map.sound.length * 60f / state.map.bpm
      #multiplier based on hits taken
      healthMultiplier = if state.totalHits == 0: 2.0 else: 1.0
      #fraction that was actually obtained
      perfectFraction = (state.points / perfectPoints).min(1f)
      #final amount based on score
      resultAmount = max((perfectFraction * maxCopper * healthMultiplier).int + (if state.map.highScore == 0: completionCopper else: 0), 1)

    state.copperReceived = resultAmount
    save.copper += resultAmount
    state.map.highScore = state.map.highScore.max(state.points)
    saveGame()

makeTimedSystem()

makeSystem("input", [GridPos, Input, UnitDraw, Pos]):
  all:
    const switchKeys = [key1, key2, key3, key4, key5, key6, key7, key8, key9, key0]

    if item.input.lastSwitchTime == 0f or musicTime() >= item.input.lastSwitchTime + switchDelay:
      for i, unit in save.units:
        if unit != item.unitDraw.unit and i < switchKeys.len and (switchKeys[i].tapped or mobileUnitSwitch == i):
          item.unitDraw.unit = unit
          item.unitDraw.switchTime = 1f
          item.input.lastSwitchTime = musicTime()
          effectCharSwitch(item.pos.vec + vec2(0f, 6f.px))
          save.lastUnit = unit
          break

    let canMove = if state.rawBeat > 0.5:
      #late - the current beat must be greater than the target
      state.turn > item.input.nextBeat
    elif state.rawBeat < 0.2:
      #early - the current beat can be equal to the target
      state.turn >= item.input.nextBeat
    else:
      false
    
    item.input.couldMove = canMove
    
    var 
      moved = false
      failed = false
      vec = if musicTime() >= item.input.lastInputTime and item.unitDraw.unit.unmoving.not: axisTap2(keyA, keyD, KeyCode.keyS, keyW) + axisTap2(keyLeft, keyRight, keyDown, keyUp) + mobilePad else: vec2()
    
    #reset pad state after polling
    mobilePad = vec2()

    #prevent going out of bounds as counting as a move
    let newPos = item.gridPos.vec + vec.vec2i
    if newPos.x.abs > mapSize or newPos.y.abs > mapSize:
      vec = vec2()

    if vec.zero.not:
      vec = vec.lim(1)
      
      if canMove:
        item.input.fails = 0

    #make direction orthogonal
    if vec.angle.deg.int.mod(90) != 0: vec.angle = vec.angle.deg.round(90f).rad
    
    if not canMove:
      #tried to move incorrectly, e.g. spam
      if vec.zero.not:
        failed = true
        item.input.fails.inc
        if item.input.fails > 1:
          item.input.lastInputTime = musicTime() + beatSpacing()

      vec = vec2()

    item.unitDraw.scl = item.unitDraw.scl.lerp(1f, 12f * fau.delta)

    if failed:
      effectFail(item.pos.vec, life = beatSpacing())
      state.misses.inc
      addPoints(-2)
      item.unitDraw.failTime = 1f

    if item.unitDraw.walkTime > 0:
      item.unitDraw.walkTime -= fau.delta * 9f

      if item.unitDraw.walkTime < 0f:
        item.unitDraw.walkTime = 0f

    item.unitDraw.shieldTime = item.unitDraw.shieldTime.lerp(item.input.shielded.float32, 10f * fau.delta)

    item.unitDraw.beatScl -= fau.delta / beatSpacing()
    item.unitDraw.beatScl = max(0f, item.unitDraw.beatScl)

    item.unitDraw.hitTime -= fau.delta / hitDuration
    item.unitDraw.failTime -= fau.delta / (beatSpacing() / 2f)
    item.unitDraw.switchTime -= fau.delta / hitDuration

    if state.newTurn and item.unitDraw.unit.unmoving.not:
      item.unitDraw.beatScl = 1f

    if vec.zero.not:
      moved = true

      item.unitDraw.beatScl = 1f
      item.input.moves.inc
      item.input.lastMove = vec.vec2i

      item.gridPos.vec += vec.vec2i
      item.gridpos.vec.clamp(vec2i(-mapSize), vec2i(mapSize))

      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec + vec2(0f, 2f.px))
      effectWalkWave(item.gridPos.vec.vec2, life = beatSpacing())

      addPoints(1)

      if vec.x.abs > 0:
        item.unitDraw.side = vec.x < 0
      
      if item.unitDraw.unit.abilityProc != nil:
        item.unitDraw.unit.abilityProc(item.entity, item.input.moves)

    #yes, this is broken with many characters, but good enough
    state.playerPos = item.gridPos.vec

    if moved:
      #check if was late
      if state.rawBeat > 0.5f:
        #late; target beat is the current one
        item.input.nextBeat = state.turn
        state.beatStats = "late"
      else:
        #early; target beat is the one after this one
        item.input.nextBeat = state.turn + 1
        state.beatStats = "early"
    
    item.input.justMoved = moved

makeSystem("runDelay", [RunDelay]):
  if state.newTurn:
    all:
      item.runDelay.delay.dec
      if item.runDelay.delay < 0:
        let p = item.runDelay.callback
        p()
        item.entity.delete()

#fade out and delete
makeSystem("deleting", [Deleting, Scaled]):
  all:
    item.deleting.time -= fau.delta / 0.2f
    item.scaled.scl = item.deleting.time
    if item.deleting.time < 0:
      item.entity.delete()

makeSystem("lifetime", [Lifetime]):
  if state.newTurn:
    all:
      item.lifetime.turns.dec

      #fade out, no damage
      if item.lifetime.turns < 0:
        if not item.entity.has(Deleting):
          item.entity.add(Deleting(time: 1f))
        if item.entity.has(Damage):
          item.entity.remove(Damage)
        if item.entity.has(Lifetime):
          item.entity.remove(Lifetime)

makeSystem("snek", [Snek, GridPos, Velocity]):
  if state.newTurn:
    all:
      if item.snek.produced.not and item.snek.gen < item.snek.len - 1:
        let copy = item.entity.clone()
        #behind this one
        copy.fetch(GridPos).vec -= item.velocity.vec
        copy.fetch(Pos).vec = copy.fetch(GridPos).vec.vec2
        copy.fetch(Snek).gen = item.snek.gen + 1
        copy.fetch(Snek).fade = 0f

        item.snek.produced = true

      item.snek.turns.inc

makeSystem("spawnEvery", [SpawnEvery]):
  if state.newTurn:
    all:
      if (state.turn + item.spawnEvery.offset).mod(item.spawnEvery.space.max(1)) == 0:
        item.entity.add item.spawnEvery.spawn

makeSystem("spawnConveyors", [GridPos, SpawnConveyors]):
  template spawn(d: Vec2i, length: int) =
    if item.spawnConveyors.dir != d:
      makeConveyor(item.gridPos.vec, d, length)

  if state.newTurn:
    all:
      if item.spawnConveyors.alldir:
        for dir in d8():
          spawn(dir, item.spawnConveyors.len)
      elif item.spawnConveyors.diagonal.not:
        for dir in d4():
          spawn(dir, item.spawnConveyors.len)
      else:
        for dir in d4edge():
          spawn(dir, item.spawnConveyors.len)

      item.entity.remove(SpawnConveyors)

makeSystem("turretFollow", [Turret, GridPos]):
  if state.newTurn and state.turn mod 2 == 0:
    let target = state.playerPos
    all:
      if item.gridPos.vec.x.abs == mapSize:
        if item.gridPos.vec.y != target.y:
          item.gridPos.vec.y += sign(target.y - item.gridPos.vec.y)
      else:
        if item.gridPos.vec.x != target.x:
          item.gridPos.vec.x += sign(target.x - item.gridPos.vec.x)

makeSystem("turretShoot", [Turret, GridPos]):
  if state.newTurn:
    all:
      item.turret.reloadCounter.inc
      if item.turret.reloadCounter >= item.turret.reload:
        makeBullet(item.gridPos.vec, item.turret.dir)
        item.turret.reloadCounter = 0
      
makeSystem("updateMap", []):
  state.map.update()

makeSystem("damagePlayer", [GridPos, Pos, Damage, not Deleting]):
  fields:
    toDelete: seq[EntityRef]

  sys.toDelete.setLen(0)

  all:
    #only actually apply damage when:
    #1. player just moved this turn, or
    #2. ~~player just skipped a turn (was too late)~~ doesn't work, looks really bad
    #3. item has approached player close enough
    #TODO maybe item movement should be based on player movement?
    var hit = false

    template deleteCurrent =
      if item.entity.has(DrawLaser):
        sys.toDelete.add item.entity
      else:
        sys.deleteList.add item.entity
      effectHit(item.gridPos.vec.vec2)
      
    #hit player first.
    for other in sysWall.groups:
      let pos = other.gridPos
      if pos.vec == item.gridPos.vec:
        deleteCurrent()
        
        other.wall.health.dec
        if other.wall.health <= 0 and not other.entity.has(Deleting):
          other.entity.add Deleting(time: 1f)
        
        #cannot damage player anymore
        hit = true

    if not hit:
      for other in sysInput.groups:
        let pos = other.gridPos
        if pos.vec == item.gridPos.vec and (other.input.justMoved or other.pos.vec.within(item.pos.vec, 0.23f)):
          other.unitDraw.hitTime = 1f
          soundHit.play()
          deleteCurrent()

          #damage shields instead
          if not other.input.shielded:
            state.hitTime = 1f
            addPoints(-15)

            #do not actually deal damage (iframes)
            if other.input.hitTurn < state.turn - 1:
              state.hits.inc
              state.totalHits.inc
              other.input.hitTurn = state.turn
          else:
            other.input.shielded = false
    
  for i in sys.toDelete:
    if i.has(Damage):
      i.remove Damage

makeSystem("updateBounce", [GridPos, Velocity, Bounce]):
  if state.newTurn:
    all:
      if item.bounce.count > 0:
        let next = item.gridPos.vec + item.velocity.vec
        var bounced = false

        if next.x.abs > mapSize:
          item.velocity.vec.x *= -1
          bounced = true
        if next.y.abs > mapSize:
          item.velocity.vec.y *= -1
          bounced = true

        if bounced:
          item.bounce.count.dec
          if item.bounce.count <= 0:
            item.entity.remove(Bounce)

makeSystem("leaveBullet", [GridPos, LeaveBullet]):
  if state.newTurn:
    all:
      makeTimedBullet(item.gridPos.vec, vec2i(), "mine", life = item.leaveBullet.life)

makeSystem("updateVelocity", [GridPos, Velocity]):
  if state.newTurn:
    all:
      if state.turn.mod(item.velocity.space.max(1)) == 0:
        item.gridPos.vec += item.velocity.vec

#TODO should not require snek...
makeSystem("collideSnek", [GridPos, Damage, Velocity, Snek]):
  if state.newTurn:
    all:
      if item.snek.turns > 0:
        for other in sys.groups:
          let pos = other.gridPos
          if other.entity != item.entity and other.velocity.vec == -item.velocity.vec and pos.vec == item.gridPos.vec:
            sys.deleteList.add item.entity
            sys.deleteList.add other.entity
            effectHit(item.gridPos.vec.vec2)

makeSystem("killOffscreen", [GridPos, Velocity, not Deleting]):
  fields:
    #must be queued for some reason, polymorph bug? investigate later
    res: seq[EntityRef]
    
  if state.newTurn:
    sys.res.setLen 0

    all:
      let p = item.gridPos.vec
      if p.x.abs > mapSize or p.y.abs > mapSize:
        sys.res.add item.entity
    
    for e in sys.res:
      e.add Deleting(time: 1f)

makeSystem("posLerp", [Pos, GridPos]):
  all:
    let a = 12f * fau.delta
    item.pos.vec.lerp(item.gridPos.vec.vec2, a)

template updateMapPreviews =
  let size = sysDraw.buffer.size
  for map in allMaps:
    if map.preview.isNil or map.preview.size != size:
      if map.preview.isNil:
        map.preview = newFramebuffer(size)
      else:
        map.preview.resize(size)

      drawBuffer(map.preview)
      if map.drawPixel != nil: map.drawPixel()
      #if map.draw != nil: map.draw()
      drawBufferScreen()

makeSystem("draw", []):
  fields:
    buffer: Framebuffer
    bloom: Bloom
  init:
    sys.bloom = newBloom()
    sys.buffer = newFramebuffer()

    for i in 0..<smokeFrames.len:
      smokeFrames[i] = patch("smoke" & $i)

    for i in 0..<explodeFrames.len:
      explodeFrames[i] = patch("explode" & $i)
    
    for i in 0..<hitFrames.len:
      hitFrames[i] = patch("hit" & $i)

  let margin = when isMobile: 3 else: 4

  #margin is currently 4, adjust as needed
  let camScl = (min(fau.size.x, fau.size.y) / ((mapSize * 2 + 1 + margin)))

  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size * tileSize / camScl)

  rawScaling = 1f / camScl

  fau.cam.use(fau.size / camScl, vec2())

  updateMapPreviews()

makeSystem("drawBackground", []):
  if mode in ingameModes:
    if state.map.drawPixel != nil:
      drawPixel:
        state.map.drawPixel()

    if state.map.draw != nil:
      state.map.draw()

makeEffectsSystem()

makeSystem("scaled", [Scaled]):
  all:
    item.scaled.time += fau.delta

makeSystem("bounceVelocity", [Velocity, DrawBounce]):
  all:
    if item.velocity.vec != vec2i():
      item.drawBounce.rotation = item.drawBounce.rotation.alerp(item.velocity.vec.angle, 10f * fau.delta)

#make sure lasers (usually) don't hit after their visual is mostly done
makeSystem("removeLaserDamage", [Pos, DrawLaser, Scaled, Damage]):
  all:
    if item.scaled.time / 0.3f > 0.5f:
      item.entity.remove Damage

makeSystem("drawSquish", [Pos, DrawSquish, Velocity, Snek, Scaled]):
  all:
    item.snek.fade += fau.delta / 0.5f
    let f = item.snek.fade.clamp

    draw(item.drawSquish.sprite.patch,
      item.pos.vec, 
      rotation = item.velocity.vec.vec2.angle,
      scl = vec2(1f, 1f - state.moveBeat * 0.3f) * item.scaled.scl,
      mixcolor = state.map.fadeColor.withA(1f - f)
    )

makeSystem("drawSpin", [Pos, DrawSpin, Scaled]):
  all:
    proc spinSprite(patch: Patch, pos: Vec2, scl: Vec2, rot: float32) =
      let r = rot.mod 90f
      draw(patch, pos, rotation = r, scl = scl)
      draw(patch, pos, rotation = r - 90f.rad, color = rgba(1f, 1f, 1f, r / 90f.rad), scl = scl)

    spinSprite(item.drawSpin.sprite.patch, item.pos.vec, vec2(1f + state.moveBeat.pow(3f) * 0.2f) * item.scaled.scl, 90f.rad * state.moveBeat.pow(6f))

makeSystem("drawBounce", [Pos, DrawBounce, Scaled]):
  all:
    draw(item.drawBounce.sprite.patch, item.pos.vec, z = zlayer(item) - 2f.px, rotation = item.drawBounce.rotation, scl = vec2(1f + state.moveBeat.pow(7f) * 0.3f) * item.scaled.scl)

makeSystem("drawLaser", [Pos, DrawLaser, Scaled]):
  all:
    let 
      fin = (item.scaled.time / 0.3f).clamp
      fout = 1f - fin
    draw("laser".patchConst, item.pos.vec, z = zlayer(item) + 1f.px, rotation = item.drawLaser.dir.vec2.angle, scl = vec2(1f, (fout.powout(4f) + fout.pow(3f) * 0.4f) * item.scaled.scl), mixcolor = colorWhite.withA(fout.pow(3f)))

makeSystem("drawUnit", [Pos, UnitDraw, Input]):
  all:

    let unit = item.unitDraw.unit
    let suffix = 
      if item.unitDraw.hitTime > 0: "-hit"
      elif item.unitDraw.failTime > 0 and (&"unit-{item.unitDraw.unit.name}-angery").patch.exists: "-angery"
      else: ""
    
    if item.unitDraw.shieldTime > 0.001f:
      draw("shield".patchConst, item.pos.vec, z = zlayer(item) - 1f, scl = vec2(item.unitDraw.shieldTime), mixColor = colorWhite.withA(item.unitDraw.hitTime.clamp))

    draw(
      (&"unit-{item.unitDraw.unit.name}{suffix}").patch,
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px),
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl) * 0.16f), 
      align = daBot,
      mixColor = colorWhite.withA(if item.unitDraw.shieldTime > 0.001f: 0f else: clamp(item.unitDraw.hitTime - 0.6f)).mix(colorAccent, item.unitDraw.switchTime.max(0f)),
      z = zlayer(item)
    )

    if unit.abilityReload > 0:
      draw(fau.white, item.pos.vec - vec2(0f, 3f.px), size = vec2(unit.abilityReload.float32.px + 2f.px, 3f.px), color = colorBlack, z = 6000f)
      for i in 0..<unit.abilityReload:
        let show = (item.input.moves mod unit.abilityReload) >= i
        draw("reload".patchConst, item.pos.vec + vec2((i.float32 - ((unit.abilityReload - 1f) / 2f)) * 1f.px, -3f.px), color = if show: %"fe8e54" else: rgb(0.4f), z = 6000f)

makeSystem("drawBullet", [Pos, DrawBullet, Velocity, Scaled]):
  all:
    #TODO glow!
    let sprite = 
      if item.drawBullet.sprite.len == 0: "bullet"
      else: item.drawBullet.sprite
    draw(sprite.patch, item.pos.vec, z = zlayer(item), rotation = item.velocity.vec.vec2.angle, mixColor = colorWhite.withA(state.moveBeat.pow(5f)), scl = item.scaled.scl.vec2#[, scl = vec2(1f - moveBeat.pow(7f) * 0.3f, 1f + moveBeat.pow(7f) * 0.3f)]#)

include menus

#unit textures dynamically loaded
preloadFolder("textures")

launchFau(initParams(title = "Animdustry"))
