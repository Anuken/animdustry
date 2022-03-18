import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/bloom

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048 --outlineFolder=outlined/")

type MusicTrack = object
  sound: Sound
  bpm: float
  beatOffset: float

type Beatmap = object
  track: MusicTrack
  draw: proc()
  update: proc()

type GameState = object
  map: Beatmap
  voice: Voice
  secs: float
  beat: float
  beatChanged: bool
  beatCount: int
  loops: int

#TODO better viewport
const
  #pixels
  tileSize = 20f
  scl = 80f
  hitDuration = 0.5f
  pixelate = false
  noMusic = false
  beatMargin = 0.025f
  mapSize = 6

var
  #track definitions
  trackDefault, trackLis, trackRiser, trackEnemy, trackDisco, trackWonder, trackStoplight, trackForYou, trackPeachBeach, trackPsych, trackBright79: MusicTrack

  #basic beat/game state
  nextMoveBeat = -1
  suppressInput = false
  lastMoveTime = 0f
  lastInputTime = 0f
  failCount = 0
  turn = 0
  moveBeat = 0f
  skippedBeat = false
  newTurn = false

  #should this be separate...?
  state = GameState()

  #misc rendering
  dfont: Font

register(defaultComponentOptions):
  type 
    Input = object
  
    GridPos = object
      vec: Vec2i
    
    UnitDraw = object
      unit: Unit
      side: bool
      beatScl: float32
      scl: float32
      hitTime: float32
      walkTime: float32
    
    Velocity = object
      vec: Vec2i
    
    Scaled = object
      scl: float32
    
    DrawBullet = object
      rot: float32
    
    DrawRouter = object

    DrawConveyor = object

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

#TODO broken
template runDelay(del: int, call: proc()) =
  discard newEntityWith(RunDelay(delay: del, callback: call))

template zlayer(entity: untyped): float32 = 1000f - entity.pos.vec.y

template makeUnit(pos: Vec2i, aunit: Unit) =
  discard newEntityWith(Input(), Pos(), GridPos(vec: pos), UnitDraw(unit: aunit))

template runTurn() =
  newTurn = true
  turn.inc
  moveBeat = 1f
  failCount = 0

template reset() =
  #TODO clear variable state
  sysAll.clear()
  sysRunDelay.clear()

  #stop old music
  if state.voice.int != 0:
    state.voice.stop()

  state = GameState(
    map: mapFirst #default map
  )

  #TODO maybe make object?
  nextMoveBeat = 0
  failCount = 0
  suppressInput = false
  lastMoveTime = 0f
  lastInputTime = 0f
  turn = 0
  moveBeat = 0f
  skippedBeat = false
  newTurn = false

  makeUnit(vec2i(), unitZenith)

template beginMap(next: Beatmap, offset = 0.0) =
  reset()

  state.map = next
  state.voice = state.map.track.sound.play()
  lastMoveTime = beatSpacing()
  if offset > 0.0:
    state.voice.seek(offset)
    turn = int(offset / beatSpacing()) - 2

proc beat(): float32 = state.beat
proc ibeat(): float32 = 1f - state.beat
proc beatSpacing(): float = 1.0 / (state.map.track.bpm / 60.0)
proc musicTime(): float = state.voice.streamPos

proc canMove(): bool =
  return (beat() > 0.5f) and state.beatCount >= nextMoveBeat

include patterns, maps

makeSystem("init", []):
  init:
    dfont = loadFont("font.ttf", size = 16)
    fau.pixelScl = 1f / tileSize
    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()

    #trackLis = MusicTrack(sound: musicLis, bpm: 113f, beatOffset: 0f / 1000f)
    trackDefault = MusicTrack(sound: musicLost, bpm: 122f, beatOffset: -10.0 / 1000.0)
    trackEnemy = MusicTrack(sound: musicEnemy, bpm: 123f, beatOffset: -250.0 / 1000.0)

    #I can actually use these:
    trackWonder = MusicTrack(sound: musicpycIWonder, bpm: 125f, beatOffset: -30f / 1000f)
    trackStoplight = MusicTrack(sound: musicStoplight, bpm: 85f, beatOffset: -50f / 1000f)
    trackForYou = MusicTrack(sound: musicAritusForYou, bpm: 126f, beatOffset: -50f / 1000f)
    trackPeachBeach = MusicTrack(sound: musicAdrianwavePeachBeach, bpm: 121, beatOffset: 0f / 1000f)
    trackBright79 = MusicTrack(sound: musicKrBright79, bpm: 127f, beatOffset: 0f / 1000f)
    #what does "fevereiro" even mean
    trackPsych = MusicTrack(sound: musicTpzPsychedFevereiro, bpm: 150, beatOffset: -20f / 1000f)

    createMaps()

    beginMap(mapFirst, offset = 20.0)

makeSystem("all", [Pos]): discard

makeSystem("updateMusic", []):
  newTurn = false
  skippedBeat = false

  when defined(debug):
    if keySpace.tapped:
      state.voice.paused = state.voice.paused.not

  if state.voice.valid and state.voice.playing:
    let beatSpace = beatSpacing()

    moveBeat -= fau.delta / beatSpace
    moveBeat = max(moveBeat, 0f)

    #check for loop???
    if state.loops != state.voice.loopCount:
      state.loops = state.voice.loopCount

      #reset state
      state.secs = 0f
      state.beatCount = 0
      state.beat = 0f
      #TODO allows skipped beat at loop end
      nextMoveBeat = 0

    state.secs = state.voice.streamPos + state.map.track.beatOffset

    let
      prevBeat = state.beatCount
      nextBeat = int(state.secs / beatSpace)

    state.beatChanged = nextBeat != state.beatCount
    state.beatCount = nextBeat
    state.beat = (1.0 - ((state.secs mod beatSpace) / beatSpace)).float32

  #force skip turns when the player takes too long; this can happen fairly frequently, so it doesn't imply the player being bad.
  if state.beatCount > nextMoveBeat or (musicTime() - lastMoveTime) / beatSpacing() >= (1f + beatMargin):
    lastMoveTime = musicTime()
    nextMoveBeat = state.beatCount
    skippedBeat = true
    suppressInput = true
    runTurn()

makeSystem("runDelay", [RunDelay]):
  if newTurn:
    all:
      item.runDelay.delay.dec
      if item.runDelay.delay < 0:
        let p = item.runDelay.callback
        p()
        item.entity.delete()

makeTimedSystem()

makeSystem("input", [GridPos, Input, UnitDraw, Pos]):
  start:
    var moved = false

    #TODO only one direction at a time?
    var vec = if musicTime() >= lastInputTime: axisTap2(keyA, keyD, keyS, keyW) else: vec2()

    #make direction orthogonal
    if vec.angle.deg.int.mod(90) != 0: vec.angle = vec.angle.deg.round(90f).rad
    
    if not canMove():
      #tried to move incorrectly, e.g. spam
      if vec.zero.not:
        failCount.inc
        if failCount > 2:
          lastInputTime = musicTime() + beatSpacing()

      vec = vec2()
  all:
    if keyEscape.tapped:
      quitApp()

    item.unitDraw.scl = item.unitDraw.scl.lerp(1f, 12f * fau.delta)

    if item.unitDraw.walkTime > 0:
      item.unitDraw.walkTime -= fau.delta * 9f

      if item.unitDraw.walkTime < 0f:
        item.unitDraw.walkTime = 0f

    item.unitDraw.beatScl -= fau.delta / beatSpacing()
    item.unitDraw.beatScl = max(0f, item.unitDraw.beatScl)

    item.unitDraw.hitTime -= fau.delta / hitDuration

    #TODO looks kinda bad when moving, less "bounce"
    if skippedBeat:
      item.unitDraw.beatScl = 1f

    if vec.zero.not:
      moved = true

      item.unitDraw.beatScl = 1f

      item.gridPos.vec += vec.vec2i

      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec + vec2(0f, 2f.px))
      effectWalkWave(item.gridPos.vec.vec2, life = beatSpacing())

      if vec.x.abs > 0:
        item.unitDraw.side = vec.x < 0
  finish:
    if moved:
      #next turn, if it has not been skipped yet
      if not suppressInput:
        runTurn()
      suppressInput = false
      nextMoveBeat = state.beatCount + 1
      lastMoveTime = musicTime()

#fade out and delete
makeSystem("deleting", [Deleting, Scaled]):
  all:
    item.deleting.time -= fau.delta / 0.2f
    item.scaled.scl = item.deleting.time
    if item.deleting.time < 0:
      item.entity.delete()

makeSystem("lifetime", [Lifetime]):
  if newTurn:
    all:
      item.lifetime.turns.dec

      #fade out, no damage
      if item.lifetime.turns < 0:
        item.entity.add(Deleting(time: 1f))
        item.entity.remove(Damage)
        item.entity.remove(Lifetime)

makeSystem("snek", [Snek, GridPos, Velocity]):
  if newTurn:
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

  if newTurn:
    all:
      if item.spawnConveyors.diagonal.not:
        for dir in d4():
          spawn(dir, item.spawnConveyors.len)
      else:
        for dir in d4edge():
          spawn(dir, item.spawnConveyors.len)

      item.entity.remove(SpawnConveyors)

makeSystem("updateMap", []):
  state.map.update()

#TODO only run during turn?
makeSystem("damagePlayer", [GridPos, Damage]):
  all:
    for other in sysInput.groups:
      let pos = other.gridPos
      if pos.vec == item.gridPos.vec:
        other.unitDraw.hitTime = 1f
        sys.deleteList.add item.entity
        effectHit(item.gridPos.vec.vec2)

makeSystem("updateVelocity", [GridPos, Velocity]):
  if newTurn:
    all:
      item.gridPos.vec += item.velocity.vec

#TODO should not require snek...
makeSystem("collideSnek", [GridPos, Damage, Velocity, Snek]):
  if newTurn:
    all:
      if item.snek.turns > 0:
        for other in sys.groups:
          let pos = other.gridPos
          if other.entity != item.entity and other.velocity.vec == -item.velocity.vec and pos.vec == item.gridPos.vec:
            sys.deleteList.add item.entity
            sys.deleteList.add other.entity
            effectHit(item.gridPos.vec.vec2)

makeSystem("killBullets", [GridPos, Velocity]):
  if newTurn:
    all:
      let p = item.gridPos.vec
      if p.x.abs > mapSize or p.y.abs > mapSize:
        delete item.entity

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
  
  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size * tileSize / scl)

  when pixelate:
    drawBuffer(sys.buffer)

  fau.cam.update(fau.size / scl, vec2())
  fau.cam.use()

makeSystem("drawBackground", []):
  state.map.draw()

makeSystem("drawTiles", []):
  for x in -mapSize..mapSize:
    for y in -mapSize..mapSize:
      let 
        absed = ((x + mapSize) + (y + mapSize) + turn).mod 5
        strength = (absed == 0).float32 * moveBeat
      draw("tile".patchConst, vec2(x, y), color = (%"ffffff").mix(colorBlue, strength).withA(0.4f), scl = vec2(1f - 0.11f * beat()))

makeEffectsSystem()

makeSystem("drawConveyor", [Pos, DrawConveyor, Velocity, Snek, Scaled]):
  all:
    item.snek.fade += fau.delta / 0.5f
    let f = item.snek.fade.clamp

    draw("conveyor".patchConst,
      item.pos.vec, 
      rotation = item.velocity.vec.vec2.angle,
      scl = vec2(1f, 1f - moveBeat * 0.3f) * item.scaled.scl,
      mixcolor = colorPink.mix(colorWhite, 0.5f).withA(1f - f)
    )

makeSystem("drawRouter", [Pos, DrawRouter, Scaled]):
  all:
    proc spinSprite(patch: Patch, pos: Vec2, scl: Vec2, rot: float32) =
      let r = rot.mod 90f
      draw(patch, pos, rotation = r, scl = scl)
      draw(patch, pos, rotation = r - 90f.rad, color = rgba(1f, 1f, 1f, r / 90f.rad), scl = scl)

    spinSprite("router".patchConst, item.pos.vec, vec2(1f + beat().pow(3f) * 0.2f) * item.scaled.scl, 90f.rad * beat().pow(6f))

makeSystem("drawUnit", [Pos, UnitDraw]):
  all:

    #looks bad
    #draw("shadow".patchConst, item.pos.vec, color = rgba(0f, 0f, 0f, 0.3f))

    draw(
      #TODO bad
      if item.unitDraw.hitTime > 0: (&"unit-{item.unitDraw.unit.name}-hit").patch else: (&"unit-{item.unitDraw.unit.name}").patch, 
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px),
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl).pow(1) * 0.14f), 
      align = daBot,
      mixColor = colorWhite.withA(clamp(item.unitDraw.hitTime - 0.6f)),
      z = zlayer(item)
    )

makeSystem("drawBullet", [Pos, DrawBullet, Velocity]):
  all:
    draw("bullet".patchConst, item.pos.vec, z = zlayer(item), rotation = item.velocity.vec.vec2.angle, mixColor = colorWhite.withA(moveBeat.pow(5f))#[, scl = vec2(1f - moveBeat.pow(7f) * 0.3f, 1f + moveBeat.pow(7f) * 0.3f)]#)

makeSystem("endDraw", []):
  drawBufferScreen()
  when pixelate:
    sysDraw.buffer.blit()

makeSystem("drawUI", []):
  let
    time = musicTime()
    minutes = time.int div 60
    secs = time.int mod 60
  dfont.draw(&"turn {turn} | beat {state.beatCount} | {minutes}:{secs:02}", fau.cam.pos + fau.cam.size * vec2(0f, 0.5f), align = daTop)

launchFau("absurd")