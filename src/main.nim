import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/ui, fau/g2/bloom, macros

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048 --outlineFolder=outlined/")

type Beatmap = object
  name: string
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

#TODO better viewport
const
  #pixels
  tileSize = 20f
  hitDuration = 0.6f
  noMusic = false
  mapSize = 6
  fftSize = 50

var
  audioLatency = 0.0
  maps: seq[Beatmap]
  state = GameState()
  mode = gmMenu
  fftValues: array[fftSize, float32]
  
register(defaultComponentOptions):
  type 
    Input = object
      hitTurn: int
      nextBeat: int
      lastInputTime: float32
      fails: int
  
    GridPos = object
      vec: Vec2i
    
    UnitDraw = object
      unit: Unit
      side: bool
      beatScl: float32
      scl: float32
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
    particlesLife(e.id, 10, e.pos, e.fin, 12f.px):
      fillCircle(pos, (4f * fout.powout(3f)).px, color = %"6e7080")
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

template reset() =
  sysAll.clear()
  sysRunDelay.clear()

  #stop old music
  if state.voice.int != 0:
    state.voice.stop()

  #make default map
  state = GameState(
    map: mapFirst
  )

  makeUnit(vec2i(), unitOct)

template playMap(next: Beatmap, offset = 0.0) =
  reset()

  state.map = next
  state.voice = state.map.sound.play()
  if offset > 0.0:
    state.voice.seek(offset)

proc beatSpacing(): float = 1.0 / (state.map.bpm / 60.0)
proc musicTime(): float = state.secs

include patterns, maps

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

    defaultFont = loadFont("font.ttf", size = 16)
    defaultButtonStyle.up = "button".patch9
    defaultButtonStyle.overColor = colorWhite.withA(0.3f)
    defaultButtonStyle.downColor = colorWhite.withA(0.5f)

    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()

    #trackLis = MusicTrack(sound: musicLis, bpm: 113f, beatOffset: 0f / 1000f)
    #trackDefault = MusicTrack(sound: musicLost, bpm: 122f, beatOffset: -10.0 / 1000.0)
    #trackEnemy = MusicTrack(sound: musicEnemy, bpm: 123f, beatOffset: -250.0 / 1000.0)

    #I can actually use these:
    #trackWonder = MusicTrack(sound: musicpycIWonder, bpm: 125f, beatOffset: -30f / 1000f)
    #trackUltra = MusicTrack(sound: musicUltra, bpm: 240f, beatOffset: 0f)
    #trackPeachBeach = MusicTrack(sound: musicAdrianwavePeachBeach, bpm: 121, beatOffset: 0f / 1000f)
    #trackBright79 = MusicTrack(sound: musicKrBright79, bpm: 127f, beatOffset: 0f / 1000f)
    #what does "fevereiro" even mean
    #trackPsych = MusicTrack(sound: musicTpzPsychedFevereiro, bpm: 150, beatOffset: -20f / 1000f)

    createMaps()
    maps = @[mapFirst, mapSecond]

    #beginMap(mapSecond, 0.0)
  
  makePaused(sysUpdateMusic, sysDeleting, sysUpdateMap, sysPosLerp, sysInput)

  if mode != gmMenu and keySpace.tapped:
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

    let
      prevBeat = state.turn
      nextBeat = int(state.secs / beatSpace)

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

    #TODO looks kinda bad when moving, less "bounce"
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

makeSystem("draw", []):
  fields:
    buffer: Framebuffer
    bloom: Bloom
  init:
    sys.bloom = newBloom()
    sys.buffer = newFramebuffer()
  
  #margin is currently 4, adjust as needed
  let camScl = (min(fau.size.x, fau.size.y) / ((mapSize * 2 + 1 + 4))).round

  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size * tileSize / camScl)

  fau.cam.update(fau.size / camScl, vec2())
  fau.cam.use()

makeSystem("drawBackground", []):
  #TODO what happens in the menu then?
  if mode != gmMenu:
    if state.map.drawPixel != nil:
      drawBuffer(sysDraw.buffer)
      state.map.drawPixel()
      drawBufferScreen()
      sysDraw.buffer.blit()

    if state.map.draw != nil:
      state.map.draw()

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

    #looks bad
    #draw("shadow".patchConst, item.pos.vec, color = rgba(0f, 0f, 0f, 0.3f))

    let suffix = 
      if item.unitDraw.hitTime > 0: "-hit"
      elif item.unitDraw.failTime > 0: "-angery"
      #TODO looks bad?
      #elif item.unitDraw.beatScl > 0.75: "-bounce"
      else: ""

    draw(
      #TODO bad
      (&"unit-{item.unitDraw.unit.name}" & suffix).patch,
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px),
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl).pow(1) * 0.14f), 
      align = daBot,
      mixColor = colorWhite.withA(clamp(item.unitDraw.hitTime - 0.6f)),
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
  if mode == gmPaused:
    defaultFont.draw("[paused]", fau.cam.pos)
  
  if mode != gmMenu:
    #draw debug text
    #TODO fancy stats
    defaultFont.draw(&"{state.turn} | {state.beatStats} | {musicTime().int div 60}:{(musicTime().int mod 60):02} | {(getAudioBufferSize() / getAudioSampleRate() * 1000):.2f}ms latency", fau.cam.pos + fau.cam.size * vec2(0f, 0.5f), align = daTop)
    defaultFont.draw(&"hits: {state.hits}", fau.cam.pos - fau.cam.size * vec2(0f, 0.5f), align = daBot)
  else:
    #draw menu

    for i, map in maps:
      if button(rectCenter(fau.cam.pos - vec2(0f, i.float32), 3f, 1f), &"[ {map.name} ]"):
        playMap(map)
        mode = gmPlaying

launchFau("absurd")