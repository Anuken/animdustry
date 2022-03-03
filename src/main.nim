import ecs, fau/presets/[basic, effects], units, strformat, math, random

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048")

type MusicTrack = object
  sound: Sound
  bpm: float
  beatOffset: float

type MusicState = ref object
  track: MusicTrack
  voice: Voice
  secs: float
  beat: float
  beatChanged: bool
  beatCount: int

#TODO better system
const
  #pixels
  tileSize = 20f
  scl = 80f
  hitDuration = 0.5f
  pixelate = false
  noMusic = false

var 
  trackDefault, trackEva, trackLis, trackRiser: MusicTrack
  musicState = MusicState()
  nextMoveBeat = -1f
  turn = 0
  skippedBeat: bool
  newTurn: bool

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
    
    DrawBullet = object
      rot: float32
    
    Damage = object
    
defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 12f.px):
      fillCircle(pos, (4f * fout.powout(3f)).px, color = %"6e7080")
  hit(lifetime = 0.9f):
    particlesLife(e.id, 10, e.pos, e.fin, 19f.px):
      fillPoly(pos, 4, (2.5f * fout.powout(3f)).px, color = colorWhite, z = 3f)

template makeUnit(pos: Vec2i, aunit: Unit) =
  discard newEntityWith(Input(), Pos(vec: pos.vec2), GridPos(vec: pos), UnitDraw(unit: aunit))

template runTurn() =
  newTurn = true
  turn.inc

template reset() =
  sysAll.clear()

  #makeUnit(vec2i(), unitQuad)
  #makeUnit(vec2i(-1, 0), unitOct)
  makeUnit(vec2i(), unitZenith)

proc beat(): float32 = musicState.beat
proc ibeat(): float32 = 1f - musicState.beat
proc beatSpacing(): float = 1.0 / (musicState.track.bpm / 60.0)

#TODO
proc canMove(): bool =
  return (beat() > 0.5f) and musicState.beatCount.float32 >= nextMoveBeat

makeSystem("init", []):
  init:
    fau.pixelScl = 1f / tileSize
    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()
    trackDefault = MusicTrack(sound: musicMerry, bpm: 125f, beatOffset: -40.0 / 1000.0)
    trackEva = MusicTrack(sound: musicEva, bpm: 50f, beatOffset: -160.0 / 1000.0)
    trackLis = MusicTrack(sound: musicLis, bpm: 113f, beatOffset: 0f / 1000f)
    trackRiser = MusicTrack(sound: musicRiser, bpm: 140f, beatOffset: 0f / 1000f)
    musicState.track = trackRiser

    reset()

makeSystem("all", [Pos]): discard

makeSystem("updateMusic", []):
  fields:
    lastPos: float
  
  newTurn = false
  skippedBeat = false
  
  if musicState.voice.valid and musicState.voice.playing:
    let beatSpace = beatSpacing()

    musicState.secs = musicState.voice.streamPos + musicState.track.beatOffset

    let 
      prevBeat = musicState.beatCount
      nextBeat = int(musicState.secs / beatSpace)

    musicState.beatChanged = nextBeat != musicState.beatCount
    musicState.beatCount = nextBeat
    musicState.beat = (1.0 - ((musicState.secs mod beatSpace) / beatSpace)).float32
  elif not musicState.voice.valid:
    musicState.voice = musicState.track.sound.play
    musicState.voice.seek(18.0)
  
  if musicState.beatCount > nextMoveBeat:
    #TODO does not handle ONE skipped beat
    #echo "beat skip: " & $nextMoveBeat
    nextMoveBeat = musicState.beatCount
    skippedBeat = true
    runTurn()

makeTimedSystem()

makeSystem("input", [GridPos, Input, UnitDraw, Pos]):
  start:
    #TODO only one direction at a time?
    let vec = if canMove(): axisTap2(keyA, keyD, keyS, keyW) else: vec2()
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
      #next turn!
      runTurn()

      item.unitDraw.beatScl = 1f
      #"left" edge, only need to wait until next edge
      nextMoveBeat = musicState.beatCount + 1f

      item.gridPos.vec += vec.vec2i

      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec + vec2(0f, 2f.px))

      if vec.x.abs > 0:
        item.unitDraw.side = vec.x < 0

makeSystem("spawnBullets", []):
  if newTurn:
    let
      x = 5
      y = rand(-5..5)
    discard newEntityWith(DrawBullet(), Pos(vec: vec2(x.float32, y.float32)), GridPos(vec: vec2i(x, y)), Velocity(vec: vec2i(-1, 0)), Damage())

#TODO O(N^2)
makeSystem("collide", [GridPos, Damage]):
  all:
    for other in sysInput.groups:
      let pos = other.gridPos
      if pos.vec == item.gridPos.vec or pos.vec == item.gridPos.vec + vec2i(0, -1):
        other.unitDraw.hitTime = 1f
        sys.deleteList.add item.entity
        effectHit(item.gridPos.vec.vec2)

makeSystem("updateVelocity", [GridPos, Velocity]):
  if newTurn:
    all:
      item.gridPos.vec += item.velocity.vec

makeSystem("killBullets", [GridPos, Velocity]):
  if newTurn:
    all:
      if item.gridPos.vec.x < -5:
        delete item.entity

makeSystem("posLerp", [Pos, GridPos]):
  all:
    let a = 12f * fau.delta
    item.pos.vec.lerp(item.gridPos.vec.vec2, a)

makeSystem("draw", []):
  fields:
    buffer: Framebuffer
  init:
    sys.buffer = newFramebuffer()
  
  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size * tileSize / scl)

  when pixelate:
    drawBuffer(sys.buffer)

  fau.cam.update(fau.size / scl, vec2())
  fau.cam.use()

makeSystem("drawBackground", []):
  poly(vec2(), 4, (45f + 15f * (musicState.beatCount mod 4).float32).px, 0f.rad, stroke = 10f.px, color = (%"9bceff").withA(beat()))

makeSystem("drawTiles", []):
  let rad = 5
  let space = 1f
  for x in -rad..rad:
    for y in -rad..rad:
      draw("tile".patchConst, vec2(x, y) * space, color = (%"ffffff").withA(0.15f), scl = vec2(1f - 0.11f * beat()))
  
  draw("tile".patchConst, vec2(0f, -7f), color = if canMove(): colorGreen else: colorRed)

makeEffectsSystem()

makeSystem("drawUnits", [Pos, UnitDraw]):
  all:

    draw(
      #TODO bad
      if item.unitDraw.hitTime > 0: (&"unit-{item.unitDraw.unit.name}-hit").patch else: (&"unit-{item.unitDraw.unit.name}").patch, 
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px), 
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl).pow(1) * 0.13f), 
      align = daBot,
      mixColor = colorWhite.withA(clamp(item.unitDraw.hitTime - 0.6f))
    )

makeSystem("drawBullets", [Pos, DrawBullet]):
  all:
    draw("bullet".patchConst, item.pos.vec)

makeSystem("endDraw", []):
  drawBufferScreen()
  when pixelate:
    sysDraw.buffer.blit()

makeSystem("drawUI", []):
  start:
    #looks bad.
    sys.paused = true

  screenMat()
  let 
    fft = getFft()
    bars = 64
    w = fau.size.x / bars.float32
  
  for i in 0..<bars:
    fillRect(w * i.float32, 0f, w, fft[i] * 10f, color = colorBlue.mix(colorWhite, i / bars.float32))
  

launchFau("absurd")