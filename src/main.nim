import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/bloom

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048 --outlineFolder=outlined/")

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
  loops: int

type Beatmap = object
  track: MusicTrack
  draw: proc()
  update: proc()

#TODO better viewport
const
  #pixels
  tileSize = 20f
  scl = 80f
  hitDuration = 0.5f
  pixelate = false
  noMusic = true
  beatMargin = 0.025f
  mapSize = 5

var
  #track definitions
  trackDefault, trackLis, trackRiser, trackEnemy, trackDisco, trackWonder, trackStoplight, trackForYou, trackPeachBeach, trackPsych, trackBright79: MusicTrack

  #basic beat/game state
  nextMoveBeat = -1
  suppressInput = false
  lastMoveTime = 0f
  lastInputTime = 0f
  turn = 0
  moveBeat = 0f
  skippedBeat: bool
  newTurn: bool

  #should this be separate...?
  curMap: Beatmap
  musicState = MusicState()

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
    
    DrawBullet = object
      rot: float32
    
    DrawRouter = object
    
    Damage = object

defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 12f.px):
      fillCircle(pos, (4f * fout.powout(3f)).px, color = %"6e7080")
  hit(lifetime = 0.9f):
    particlesLife(e.id, 10, e.pos, e.fin, 19f.px):
      fillPoly(pos + vec2(0f, 2f.px), 4, (2.5f * fout.powout(3f)).px, color = colorWhite, z = 3000f)

GridPos.onAdd:
  let pos = entity.fetch(Pos)
  if pos.valid:
    pos.vec = curComponent.vec.vec2

template zlayer(entity: untyped): float32 = 1000f - entity.pos.vec.y

template makeUnit(pos: Vec2i, aunit: Unit) =
  discard newEntityWith(Input(), Pos(), GridPos(vec: pos), UnitDraw(unit: aunit))

template runTurn() =
  newTurn = true
  turn.inc
  moveBeat = 1f

template reset() =
  #TODO clear state
  sysAll.clear()

  #stop old music
  if musicState.voice.int != 0:
    musicState.voice.stop()

  curMap = mapFirst
  musicState.track = curMap.track

  #makeUnit(vec2i(1, 0), unitQuad)
  #makeUnit(vec2i(-1, 0), unitOct)
  makeUnit(vec2i(), unitOct)

  for pos in d4edge():
    discard newEntityWith(Pos(), GridPos(vec: pos * 5), DrawRouter())

proc beat(): float32 = musicState.beat
proc ibeat(): float32 = 1f - musicState.beat
proc beatSpacing(): float = 1.0 / (musicState.track.bpm / 60.0)
#TODO bad granulatity?
proc musicTime(): float = musicState.voice.streamPos

#TODO
proc canMove(): bool =
  return (beat() > 0.5f) and musicState.beatCount >= nextMoveBeat

include bullets, patterns, maps

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

    reset()

makeSystem("all", [Pos]): discard

makeSystem("updateMusic", []):
  newTurn = false
  skippedBeat = false

  when defined(debug):
    if keySpace.tapped:
      musicState.voice.paused = musicstate.voice.paused.not

  if musicState.voice.valid and musicState.voice.playing:
    let beatSpace = beatSpacing()

    moveBeat -= fau.delta / beatSpace
    moveBeat = max(moveBeat, 0f)

    #check for loop
    if musicState.loops != musicState.voice.loopCount:
      musicState.loops = musicState.voice.loopCount

      #reset state
      musicState.secs = 0f
      musicState.beatCount = 0
      musicState.beat = 0f
      #TODO allows skipped beat at loop end
      nextMoveBeat = 0

    musicState.secs = musicState.voice.streamPos + musicState.track.beatOffset

    let
      prevBeat = musicState.beatCount
      nextBeat = int(musicState.secs / beatSpace)

    musicState.beatChanged = nextBeat != musicState.beatCount
    musicState.beatCount = nextBeat
    musicState.beat = (1.0 - ((musicState.secs mod beatSpace) / beatSpace)).float32
  elif not musicState.voice.valid:
    musicState.voice = musicState.track.sound.play(loop = true)
    musicState.voice.seek(60.0)

  #force skip turns when the player takes too long; this can happen fairly frequently, so it doesn't imply the player being bad.
  if musicState.beatCount > nextMoveBeat or (musicTime() - lastMoveTime) / beatSpacing() >= (1f + beatMargin):
    lastMoveTime = musicTime()
    nextMoveBeat = musicState.beatCount
    skippedBeat = true
    suppressInput = true
    runTurn()

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
        lastInputTime = musicTime() + beatSpacing() * 0.9f

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

      if vec.x.abs > 0:
        item.unitDraw.side = vec.x < 0
  finish:
    if moved:
      #next turn, if it has not been skipped yet
      if not suppressInput:
        runTurn()
      suppressInput = false
      nextMoveBeat = musicState.beatCount + 1
      lastMoveTime = musicTime()

#TODO
makeSystem("spawnBullets", []):
  curMap.update()

#TODO O(N^2)
makeSystem("collide", [GridPos, Damage]):
  all:
    for other in sysInput.groups:
      let pos = other.gridPos
      #TODO should the head collide with bullets? it's a bit confusing if it doesn't
      if pos.vec == item.gridPos.vec:# or pos.vec == item.gridPos.vec + vec2i(0, -1):
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
  curMap.draw()

  #patStripes()
  #patFadeShapes()
  #patBeatSquare()
  #patFft()

makeSystem("drawTiles", []):
  for x in -mapSize..mapSize:
    for y in -mapSize..mapSize:
      let 
        absed = ((x + mapSize) + (y + mapSize) + turn).mod 5
        strength = (absed == 0).float32 * moveBeat
      draw("tile".patchConst, vec2(x, y), color = (%"ffffff").mix(colorBlue, strength).withA(0.4f), scl = vec2(1f - 0.11f * beat()))

makeEffectsSystem()

makeSystem("drawRouter", [Pos, DrawRouter]):
  all:
    proc spinSprite(patch: Patch, pos: Vec2, scl: Vec2, rot: float32) =
      let r = rot.mod 90f
      draw(patch, pos, rotation = r, scl = scl)
      draw(patch, pos, rotation = r - 90f.rad, color = rgba(1f, 1f, 1f, r / 90f.rad), scl = scl)

    spinSprite("router".patchConst, item.pos.vec, vec2(1f + beat().pow(3f) * 0.2f), 90f.rad * beat().pow(6f))

makeSystem("drawUnit", [Pos, UnitDraw]):
  all:

    #looks bad
    #draw("shadow".patchConst, item.pos.vec, color = rgba(0f, 0f, 0f, 0.3f))

    draw(
      #TODO bad
      if item.unitDraw.hitTime > 0: (&"unit-{item.unitDraw.unit.name}-hit").patch else: (&"unit-{item.unitDraw.unit.name}").patch, 
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px), 
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl).pow(1) * 0.13f), 
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
    minutes = musicState.secs.int div 60
    secs = musicState.secs.int mod 60
  dfont.draw(&"turn {turn} | {minutes}:{secs:02}", fau.cam.pos + fau.cam.size * vec2(0f, 0.5f), align = daTop)

launchFau("absurd")