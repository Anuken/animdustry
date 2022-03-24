import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/ui, fau/g2/bloom, macros, options, fau/assets, strutils, algorithm

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048 --outlineFolder=outlined/")

type Beatmap = ref object
  name: string
  songName: string
  #draws backgrounds with the pixelation buffer
  drawPixel: proc()
  #draws non-pixelated background (tiles)
  draw: proc()
  #creates patterns
  update: proc()
  #used for conveyors and other objects fading in
  fadeColor: Color
  #music track to use
  sound: Sound
  #bpm for the music track
  bpm: float
  #in seconds
  beatOffset: float
  #can be null! this is pixelated
  preview: Framebuffer

type Gamemode = enum
  gmMenu,
  gmPlaying,
  gmPaused

type GameState = object
  map: Beatmap
  #currently playing voice ID
  voice: Voice
  #smoothed position of the music track in seconds
  secs: float
  #last "discrete" music track position, internally used
  lastSecs: float
  #smooth game time, may not necessarily match seconds. visuals only!
  time: float32
  #last known player position
  playerPos: Vec2i
  #Raw beat calculated based on music position
  rawBeat: float
  #Beat calculated as countdown after a music beat happens. Smoother, but less precise.
  moveBeat: float32
  #if true, a new turn was just fired this rame
  newTurn: bool
  #beats that have passed total
  turn: int
  hits: int
  beatStats: string

#Persistent user data.
type SaveState = object
  #all units that the player has collected (should be unique)
  units: seq[Unit]
  #"gambling tokens"
  points: int
  #how many times the player has gambled
  rolls: int

#TODO better viewport
const
  #pixels
  tileSize = 20f
  hitDuration = 0.6f
  noMusic = false
  mapSize = 6
  fftSize = 50
  pointsForRoll = 10
  colorAccent = %"ffd37f"
  colorUi = %"bfecf3"
  #time between character switches
  switchDelay = 1f
  transitionTime = 0.3f
  transitionPow = 4f

var
  audioLatency = 0.0
  maps: seq[Beatmap]
  #Per-map state. Resets between games.
  state = GameState()
  #Persistent save state.
  save = SaveState()
  mode = gmMenu
  fftValues: array[fftSize, float32]
  titleFont: Font

  #UI state section

  smokeFrames: array[6, Patch]
  #currently shown unit in splash screen, null when no unit
  splashUnit: Option[Unit]
  #splash screen fade-in time
  splashTime: float32
  #increments when paused
  pauseTime: float32
  
  #transition time for fading between scenes
  #when fading out, this will reach 1, call fadeTarget, and the fade back from 1 to 0
  fadeTime: float32
  #proc that will handle the fade-in when it happens - can be nil!
  fadeTarget: proc()

register(defaultComponentOptions):
  type 
    Input = object
      hitTurn: int
      nextBeat: int
      lastInputTime: float32
      lastSwitchTime: float32
      fails: int
  
    GridPos = object
      vec: Vec2i
    
    UnitDraw = object
      unit: Unit
      side: bool
      beatScl: float32
      scl: float32
      switchTime: float32
      hitTime: float32
      walkTime: float32
      failTime: float32
    
    Velocity = object
      vec: Vec2i
    
    Scaled = object
      scl: float32
    
    DrawBullet = object
      rot: float32
      sprite: string
    
    DrawRouter = object

    DrawConveyor = object

    DrawTurret = object
      sprite: string

    Turret = object
      dir: Vec2i
      reload: int
      reloadCounter: int

    Lifetime = object
      turns: int
    
    Deleting = object
      time: float32

    Snek = object
      turns: int
      produced: bool
      gen: int
      fade: float32
      len: int
    
    SpawnConveyors = object
      len: int
      diagonal: bool
    
    Damage = object

    RunDelay = object
      delay: int
      callback: proc()

defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 13f.px):
      draw(smokeFrames[(fin.pow(2f) * smokeFrames.len).int.min(smokeFrames.high)], pos, color = %"a6a7b6")
  charSwitch(lifetime = 1f):
    particlesLife(e.id, 13, e.pos, e.fin + 0.2f, 20f.px):
      draw(smokeFrames[(fin.pow(2f) * smokeFrames.len).int.min(smokeFrames.high)], pos, color = colorAccent, z = 3000f)
  walkWave:
    poly(e.pos, 4, e.fin.powout(6f) * 1f + 4f.px, stroke = 5f.px, color = colorWhite.withA(e.fout * 0.8f), rotation = 45f.rad)
  hit(lifetime = 0.9f):
    particlesLife(e.id, 10, e.pos, e.fin, 19f.px):
      fillPoly(pos + vec2(0f, 2f.px), 4, (2.5f * fout.powout(3f)).px, color = colorWhite, z = 3000f)
  warn:
    poly(e.pos, 4, e.fout.pow(2f) * 0.6f + 0.5f, stroke = 4f.px * e.fout + 2f.px, color = colorWhite, rotation = 45f.rad)
    draw(fau.white, e.pos, size = vec2(16f.px), color = colorWhite.withA(e.fin))
  warnBullet:
    #poly(e.pos, 4, e.fout.pow(2f) * 0.6f + 0.5f, stroke = 4f.px * e.fout + 2f.px, color = colorWhite, rotation = 45f.rad)
    draw("bullet".patchConst, e.pos, size = vec2(16f.px), mixColor = colorWhite, color = colorWhite.withA(e.fin))
  
  fail:
    draw("fail".patchConst, e.pos, color = colorWhite.withA(e.fout), scl = vec2(1f) + e.fout.pow(4f) * 0.6f)

#snap position to grid position
GridPos.onAdd:
  let pos = entity.fetch(Pos)
  if pos.valid:
    pos.vec = curComponent.vec.vec2

DrawRouter.onAdd:
  if not entity.has(Scaled):
    entity.add Scaled(scl: 1f)

DrawConveyor.onAdd:
  if not entity.has(Scaled):
    entity.add Scaled(scl: 1f)

DrawTurret.onAdd:
  if not entity.has(Scaled):
    entity.add Scaled(scl: 1f)

DrawBullet.onAdd:
  if not entity.has(Scaled):
    entity.add Scaled(scl: 1f)

#unit textures dynamically loaded
preloadFolder("textures")

include saveio

#All passed systems will be paused when game state is not playing
macro makePaused(systems: varargs[untyped]): untyped =
  result = newStmtList()
  for sys in systems:
    result.add quote do:
      `sys`.paused = (mode != gmPlaying)

template runDelay(body: untyped) =
  discard newEntityWith(RunDelay(delay: 0, callback: (proc() =
    body
  )))

template zlayer(entity: untyped): float32 = 1000f - entity.pos.vec.y

template makeUnit(pos: Vec2i, aunit: Unit) =
  discard newEntityWith(Input(nextBeat: -1), Pos(), GridPos(vec: pos), UnitDraw(unit: aunit))

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

template showSplashUnit(unit: Unit) =
  splashUnit = unit.some
  splashTime = 0f

template reset() =
  sysAll.clear()
  sysRunDelay.clear()

  #stop old music
  if state.voice.int != 0:
    state.voice.stop()

  #make default map
  state = GameState(
    map: map1
  )
  
  #start with first unit
  makeUnit(vec2i(), save.units[0])

template playMap(next: Beatmap, offset = 0.0) =
  reset()

  state.map = next
  state.voice = state.map.sound.play()
  if offset > 0.0:
    state.voice.seek(offset)

proc fading(): bool = fadeTarget != nil

proc beatSpacing(): float = 1.0 / (state.map.bpm / 60.0)
proc musicTime(): float = state.secs

proc unlocked(unit: Unit): bool =
  for u in save.units:
    if u == unit: return true

proc sortUnits =
  save.units.sort do (a, b: Unit) -> int:
    cmp(allUnits.find(a), allUnits.find(b))

include patterns, maps, unitdraw

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

    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()

    createMaps()
    maps = @[map1, map2, map3, map4, map5]

    loadGame()
    createUnitDraw()

    #must have at least one unit as a default
    if save.units.len == 0:
      save.units.add unitMono
    
    sortUnits()
  
  makePaused(sysUpdateMusic, sysDeleting, sysUpdateMap, sysPosLerp, sysInput, sysTimed)

  if mode != gmMenu and (keySpace.tapped or keyEscape.tapped):
    mode = if mode != gmPlaying: gmPlaying else: gmPaused

  when defined(debug):
    
    if keyEscape.tapped:
      quitApp()

makeSystem("all", [Pos]): discard

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

makeTimedSystem()

makeSystem("input", [GridPos, Input, UnitDraw, Pos]):
  all:
    const switchKeys = [key1, key2, key3, key4, key5, key6, key7, key8, key9, key0]

    if item.input.lastSwitchTime == 0f or musicTime() >= item.input.lastSwitchTime + switchDelay:
      for i, unit in save.units:
        if unit != item.unitDraw.unit and i < switchKeys.len and switchKeys[i].tapped:
          item.unitDraw.unit = unit
          item.unitDraw.switchTime = 1f
          item.input.lastSwitchTime = musicTime()
          effectCharSwitch(item.pos.vec + vec2(0f, 6f.px))
          break

    let canMove = if state.rawBeat > 0.5:
      #late - the current beat must be greater than the target
      state.turn > item.input.nextBeat
    elif state.rawBeat < 0.2:
      #early - the current beat can be equal to the target
      state.turn >= item.input.nextBeat
    else:
      false

    var moved = false
    var failed = false

    #TODO only one direction at a time?
    var vec = if musicTime() >= item.input.lastInputTime: axisTap2(keyA, keyD, keyS, keyW) + axisTap2(keyLeft, keyRight, keyDown, keyUp) else: vec2()

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
    
    #yes, this is broken with many characters, but good enough
    state.playerPos = item.gridPos.vec

    item.unitDraw.scl = item.unitDraw.scl.lerp(1f, 12f * fau.delta)

    if failed:
      effectFail(item.pos.vec, life = beatSpacing())
      item.unitDraw.failTime = 1f

    if item.unitDraw.walkTime > 0:
      item.unitDraw.walkTime -= fau.delta * 9f

      if item.unitDraw.walkTime < 0f:
        item.unitDraw.walkTime = 0f

    item.unitDraw.beatScl -= fau.delta / beatSpacing()
    item.unitDraw.beatScl = max(0f, item.unitDraw.beatScl)

    item.unitDraw.hitTime -= fau.delta / hitDuration
    item.unitDraw.failTime -= fau.delta / (beatSpacing() / 2f)
    item.unitDraw.switchTime -= fau.delta / hitDuration

    if state.newTurn:
      item.unitDraw.beatScl = 1f

    if vec.zero.not:
      moved = true

      item.unitDraw.beatScl = 1f

      item.gridPos.vec += vec.vec2i
      item.gridpos.vec.clamp(vec2i(-mapSize), vec2i(mapSize))

      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec + vec2(0f, 2f.px))
      effectWalkWave(item.gridPos.vec.vec2, life = beatSpacing())

      if vec.x.abs > 0:
        item.unitDraw.side = vec.x < 0

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
        item.entity.add(Deleting(time: 1f))
        item.entity.remove(Damage)
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

      #if item.snek.turns > 5:
      #  sys.deleteList.add item.entity

makeSystem("spawnConveyors", [GridPos, SpawnConveyors]):
  template spawn(d: Vec2i, length: int) =
    discard newEntityWith(DrawConveyor(), Pos(), GridPos(vec: item.gridPos.vec), Velocity(vec: d), Damage(), Snek(len: length))

  if state.newTurn:
    all:
      if item.spawnConveyors.diagonal.not:
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
        discard newEntityWith(DrawBullet(), Pos(), GridPos(vec: item.gridPos.vec), Velocity(vec: item.turret.dir), Damage())
        item.turret.reloadCounter = 0
      
makeSystem("updateMap", []):
  state.map.update()

makeSystem("damagePlayer", [GridPos, Damage]):
  all:
    for other in sysInput.groups:
      let pos = other.gridPos
      if pos.vec == item.gridPos.vec:
        other.unitDraw.hitTime = 1f
        sys.deleteList.add item.entity
        effectHit(item.gridPos.vec.vec2)

        #do not actually deal damage (iframes)
        if other.input.hitTurn < state.turn - 1:
          state.hits.inc
          other.input.hitTurn = state.turn

makeSystem("updateVelocity", [GridPos, Velocity]):
  if state.newTurn:
    all:
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
  for map in maps:
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

  #margin is currently 4, adjust as needed
  let camScl = (min(fau.size.x, fau.size.y) / ((mapSize * 2 + 1 + 4))).round

  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size * tileSize / camScl)

  fau.cam.update(fau.size / camScl, vec2())
  fau.cam.use()

  updateMapPreviews()

makeSystem("drawBackground", []):
  if mode != gmMenu:
    if state.map.drawPixel != nil:
      drawPixel:
        state.map.drawPixel()

    if state.map.draw != nil:
      state.map.draw()
  elif splashUnit.isNone: 
    #draw menu background
    drawPixel:
      patStripes(%"accce3", %"57639a")

makeEffectsSystem()

makeSystem("drawConveyor", [Pos, DrawConveyor, Velocity, Snek, Scaled]):
  all:
    item.snek.fade += fau.delta / 0.5f
    let f = item.snek.fade.clamp

    draw("conveyor".patchConst,
      item.pos.vec, 
      rotation = item.velocity.vec.vec2.angle,
      scl = vec2(1f, 1f - state.moveBeat * 0.3f) * item.scaled.scl,
      mixcolor = state.map.fadeColor.withA(1f - f)
    )

makeSystem("drawRouter", [Pos, DrawRouter, Scaled]):
  all:
    proc spinSprite(patch: Patch, pos: Vec2, scl: Vec2, rot: float32) =
      let r = rot.mod 90f
      draw(patch, pos, rotation = r, scl = scl)
      draw(patch, pos, rotation = r - 90f.rad, color = rgba(1f, 1f, 1f, r / 90f.rad), scl = scl)

    spinSprite("router".patchConst, item.pos.vec, vec2(1f + state.moveBeat.pow(3f) * 0.2f) * item.scaled.scl, 90f.rad * state.moveBeat.pow(6f))

makeSystem("drawTurret", [Pos, DrawTurret, Turret, Scaled]):
  all:
    draw(item.drawTurret.sprite.patch, item.pos.vec, z = zlayer(item), rotation = item.turret.dir.vec2.angle - 90f.rad, scl = vec2(1f + state.moveBeat.pow(7f) * 0.3f) * item.scaled.scl)

makeSystem("drawUnit", [Pos, UnitDraw]):
  all:

    let suffix = 
      if item.unitDraw.hitTime > 0: "-hit"
      elif item.unitDraw.failTime > 0 and (&"unit-{item.unitDraw.unit.name}-angery").patch.exists: "-angery"
      else: ""

    draw(
      (&"unit-{item.unitDraw.unit.name}{suffix}").patch,
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px),
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl) * 0.16f), 
      align = daBot,
      mixColor = colorWhite.withA(clamp(item.unitDraw.hitTime - 0.6f)).mix(colorAccent, item.unitDraw.switchTime.max(0f)),
      z = zlayer(item)
    )

makeSystem("drawBullet", [Pos, DrawBullet, Velocity, Scaled]):
  all:
    #TODO glow!
    let sprite = 
      if item.drawBullet.sprite.len == 0: "bullet"
      else: item.drawBullet.sprite
    draw(sprite.patch, item.pos.vec, z = zlayer(item), rotation = item.velocity.vec.vec2.angle, mixColor = colorWhite.withA(state.moveBeat.pow(5f)), scl = item.scaled.scl.vec2#[, scl = vec2(1f - moveBeat.pow(7f) * 0.3f, 1f + moveBeat.pow(7f) * 0.3f)]#)

makeSystem("drawUI", []):
  fields:
    #epic hardcoded array size (it really doesn't get any better than this)
    levelFade: array[32, float32]
    unitFade: array[32, float32]
    glowPatch: Patch9
  init:
    sys.glowPatch = "glow".patch9

  drawFlush()

  if mode == gmPaused:
    pauseTime += fau.delta / 0.5f
    pauseTime = min(pauseTime, 1f)

    let midrad = 5f * pauseTime.powout(8)

    fillPoly(vec2(), 4, midrad, color = rgba(0f, 0f, 0f, 0.5f))
    poly(vec2(), 4, midrad, stroke = 4f.px, color = colorUi)

    defaultFont.draw("[ paused ]", vec2(0f, 0.5f), scale = fau.pixelScl * (1f + 2.5f * (1f - pauseTime.powout(5f))))

    if button(rectCenter(vec2(fau.cam.viewport.centerX, fau.cam.viewport.y).lerp(vec2(), pauseTime.powout(8f)) - vec2(0f, 0.5f), 3f, 1f), "Menu"):
      safeTransition:
        reset()
        mode = gmMenu
  else:
    pauseTime = 0f

  if mode != gmMenu:
    #draw debug text
    defaultFont.draw(&"{state.turn} | {state.beatStats} | {musicTime().int div 60}:{(musicTime().int mod 60):02} | {(getAudioBufferSize() / getAudioSampleRate() * 1000):.2f}ms latency", fau.cam.pos + fau.cam.size * vec2(0f, 0.5f), align = daTop)
    defaultFont.draw(&"hits: {state.hits}", fau.cam.pos - fau.cam.size * vec2(0f, 0.5f), align = daBot)

    #TODO:
    #- proper hits
    #- progress bar
    #- unit switching

    let screen = fau.cam.viewport
    if sysInput.groups.len > 0:
      let player = sysInput.groups[0]

      for i, unit in save.units:
        let 
          pos = screen.xy + vec2(i.float32 * 1f, 0f)
          current = player.unitDraw.unit == unit
        draw(patch(&"unit-{unit.name}"), pos, align = daBotLeft, mixColor = if current: rgb(0.1f).withA(0.8f) else: colorClear)
        defaultFont.draw($(i + 1), rect(pos + vec2(4f.px, -2f.px), 1f.vec2), align = daBotLeft, color = if current: colorGray else: colorWhite)

  elif splashUnit.isSome: #draw splash unit
    splashTime += fau.delta / 4f
    splashTime = min(splashTime, 1f)

    let
      unit = splashUnit.get
      pos = vec2(0f, -5f.px)
      screen = fau.cam.viewport
      titleBounds = screen.grow(-0.4f)
      subtitleBounds = screen.grow(-2.2f)
      fullPatch = patch(&"{unit.name}-real")

    if not unit.draw.isNil:
      unit.draw(unit, pos)
    
    #draw title and other UI
    titleFont.draw(
      unit.title, 
      titleBounds.xy, 
      bounds = titleBounds.wh, 
      scale = 1.5f.px,
      color = colorWhite,#.mix(%"ffcc74", fau.time.sin(0.5f, 0.5f).abs), 
      align = daTop, 
      modifier = (proc(index: int, offset: var fmath.Vec2, color: var Color, draw: var bool) =
        offset.x += ((index + 0.5f) - unit.title.len/2f) * 15f.px * splashTime.powout(3f)
        let si = (-fau.time * 0.7f + index * 0.3f).sin(0.2f, 1f)
        #offset.y -= si.max(0f) * 5f.px
        #color = colorWhite.mix(%"84f490", si * 0.8f)
      )
    )

    #draw non-waifu sprite
    for i in signs():
      draw(fullPatch, vec2(screen.centerX + unit.title.len/2f * (0.9f + splashTime.powout(3f) * 0.9f) * i.float32, screen.top - 0.75f))

    defaultFont.draw(unit.subtitle, subtitleBounds, color = rgb(0.8f), align = daTop, scale = 0.75f.px)

    if button(rectCenter(screen.x + 2f, screen.y + 1f, 3f, 1f), "Back"):
      safeTransition:
        unit.clearTextures()
        splashUnit = none[Unit]()
        splashTime = 0f
    
    #flash
    draw(fau.white, fau.cam.pos, size = fau.cam.size, color = rgba(1f, 1f, 1f, 1f - splashTime.powout(6f)))
  else:
    #draw menu

    let
      screen = fau.cam.viewport
      #height of stats box
      statsh = screen.h * 0.2f
      statsBounds = rect(screen.xy + vec2(0f, screen.h - statsh), screen.w, statsh)
      #bounds of level select buttons
      bounds = rect(screen.x, screen.y, screen.w, screen.h - statsh)
      sliced = bounds.w / maps.len
      mouse = fau.mouseWorld
      vertLen = 0.8f
      fadeCol = colorBlack.withA(0.7f)
      panMove = 1f
      unitSpace = 25f.px
    
    let buttonY = statsBounds.y + 35f.px + 0.75f + 2.px

    #gambling interface
    text(rectCenter(statsBounds.centerX + 4f, buttonY, 3f, 1f), &"{save.points} / {pointsForRoll}", align = daLeft, color = if save.points >= pointsForRoll: colorWhite else: %"ff4843")
    draw("copper".patchConst, vec2(statsBounds.centerX + 2f, buttonY))

    var bstyle = defaultButtonStyle
    bstyle.textUpColor = (%"ffda8c").mix(colorWhite, fau.time.sin(0.3f, 1f))

    #TODO gambling implementation
    if button(rectCenter(statsBounds.centerX, buttonY, 3f, 1f), "Gamble", disabled = save.points < pointsForRoll, style = bstyle):
      discard

    for i, unit in allUnits:
      let
        unlock = true#unit.unlocked #TODO uncomment once testing is over
        x = statsBounds.centerX - allUnits.len * unitSpace/2f + i.float32 * unitSpace
        y = statsBounds.y + 6f.px
        hit = rect(x - unitSpace/2f, y, unitSpace, 32f.px)
        over = hit.contains(mouse) and unlock
      
      unit.fade = unit.fade.lerp(over.float32, fau.delta * 20f)

      if over and not unit.wasOver:
        unit.jumping = true
      
      unit.wasOver = over

      unit.clickTime -= fau.delta / 0.2f

      #TODO make it hold-able?
      if over and keyMouseRight.tapped:
        unit.clickTime = 1f
        if unit == unitBoulder:
          soundVineboom.play()
      
      #TODO
      if over and keyMouseLeft.tapped:
        showSplashUnit(unit)

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
        scl = vec2(1f + click * 0.1f, 1f - click * 0.1f)
      )
    
    #outline around everything
    lineRect(statsBounds, stroke = 2f.px, color = colorUi, margin = 1f.px)

    #draw map select
    for i in countdown(maps.len - 1, 0):
      let map = maps[i]
      assert map.preview != nil

      var
        offset = sys.levelFade[i]
        r = rect(bounds.x + sliced * i.float32, bounds.y, sliced, bounds.h)
        over = r.contains(mouse)

      sys.levelFade[i] = offset.lerp(over.float32, fau.delta * 20f)
      
      #only expands after bounds check to prevent weird input
      r.w += offset * panMove

      var region = initPatch(map.preview.texture, (r.xy - screen.xy) / screen.wh, (r.topRight - screen.xy) / screen.wh)
      swap(region.v, region.v2)

      drawRect(region, r.x, r.y, r.w, r.h, mixColor = if over: colorWhite.withA(0.2f) else: colorClear, blend = blendDisabled)
      lineRect(r, stroke = 2f.px, color = map.fadeColor * (1.5f + offset * 0.5f), margin = 1f.px)

      let patchBounds = r

      if offset > 0.001f:
        sys.glowPatch.draw(patchBounds.grow(16f.px), color = colorWhite.withA(offset * (0.8f + fau.time.sin(0.2f, 0.2f))), scale = fau.pixelScl, blend = blendAdditive, z = 2f)

      #map name
      text(r - rect(vec2(), 0f, offset * 8f.px), &"Map {i + 1}", align = daTop)
      #song name (fade in?)
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
      if over and keyMouseLeft.tapped:
        capture map:
          safeTransition:
            playMap(map)
            mode = gmPlaying
  
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

launchFau("absurd")