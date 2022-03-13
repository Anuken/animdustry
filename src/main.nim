import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/bloom

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
  loops: int

#TODO better viewport
const
  #pixels
  tileSize = 20f
  scl = 80f
  hitDuration = 0.5f
  pixelate = false
  noMusic = false

var 
  trackDefault, trackLis, trackRiser, trackEnemy, trackDisco, trackWonder, trackStoplight, trackForYou, trackPeachBeach, trackPsych: MusicTrack
  musicState = MusicState()
  nextMoveBeat = -1
  turn = 0
  moveBeat = 0f
  skippedBeat: bool
  newTurn: bool
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
  moveBeat = 1f

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
  return (beat() > 0.5f) and musicState.beatCount >= nextMoveBeat

makeSystem("init", []):
  init:
    dfont = loadFont("font.ttf", size = 16)
    fau.pixelScl = 1f / tileSize
    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()
    trackDefault = MusicTrack(sound: musicLost, bpm: 122f, beatOffset: -10.0 / 1000.0)
    trackEnemy = MusicTrack(sound: musicEnemy, bpm: 123f, beatOffset: -250.0 / 1000.0)

    #I can actually use these:
    trackWonder = MusicTrack(sound: musicpycIWonder, bpm: 125f, beatOffset: -30f / 1000f)
    trackStoplight = MusicTrack(sound: musicStoplight, bpm: 85f, beatOffset: -50f / 1000f)
    trackForYou = MusicTrack(sound: musicAritusForYou, bpm: 126f, beatOffset: -50f / 1000f)
    trackPeachBeach = MusicTrack(sound: musicAdrianwavePeachBeach, bpm: 121, beatOffset: 0f / 1000f)
    #what does "fevereiro" even mean
    trackPsych = MusicTrack(sound: musicTpzPsychedFevereiro, bpm: 150, beatOffset: 0f / 1000f)
    #trackEva = MusicTrack(sound: musicEva, bpm: 50f, beatOffset: -160.0 / 1000.0)
    #trackLis = MusicTrack(sound: musicLis, bpm: 113f, beatOffset: 0f / 1000f)
    #trackRiser = MusicTrack(sound: musicRiser, bpm: 140f, beatOffset: 0f / 1000f)
    musicState.track = trackForYou

    reset()

makeSystem("all", [Pos]): discard

makeSystem("updateMusic", []):
  fields:
    lastPos: float
  
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
    #musicState.voice.seek(32.0)
    musicState.voice.seek(223.0)

  if musicState.beatCount > nextMoveBeat:# or (musicState.beatChanged and nextMoveBeat == musicState.beatCount):
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
      nextMoveBeat = musicState.beatCount + 1

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
      y = turn mod 11 - 5
    #TODO
    #discard newEntityWith(DrawBullet(), Pos(vec: vec2(x.float32, y.float32)), GridPos(vec: vec2i(x, y)), Velocity(vec: vec2i(-1, 0)), Damage())

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
  #moving stripes
  let 
    amount = 20
    swidth = 70f.px
    ang = 135f.rad
  for i in 0..<amount:
    let 
      frac = (i + turn + ((1f - moveBeat).powout(8f))).mod(amount) / amount - 0.5f
      pos = vec2l(ang, swidth) * (frac * amount)
    draw(fau.white, pos, size = vec2(swidth, 1200f.px), rotation = ang, color = colorPink.mix(colorWhite, (i.float32 mod 2f) * 0.2f))

  #basic fade squares
  poly(vec2(), 4, (45f + 15f * (musicState.beatCount mod 4).float32).px, 0f.rad, stroke = 10f.px, color = colorPink.mix(colorWhite, 0.7f).withA(beat()))

  #drawBuffer(sysDraw.bloom.buffer)

  #fading particles?
  let 
    parts = 70
    partRange = 13f
    move = vec2(-0.5f, -0.5f)
    col = colorPink.mix(colorWhite, 0.4f)
    size = (5f + beat().pow(2f) * 4f).px
  
  var r = initRand(1)
  
  for i in 0..<parts:
    var pos = vec2(r.range(partRange), r.range(partRange))

    pos += move * (turn + (1f - moveBeat).powout(30f))
    pos = (pos + partRange).emod(vec2(partRange * 2)) - partRange

    fillPoly(pos, 4, size, color = col)
    fillPoly(pos - move*0.5f, 4, size/2f, color = col)
    fillPoly(pos - move*0.9f, 4, size/4f, color = col)
  
  #when pixelate:
  #  drawBuffer(sys.buffer)
  #else:
  #  drawBufferScreen()
  
  #sysDraw.bloom.blit(meshParams(blend = blendNormal))

const bars = 50

makeSystem("drawBars", []):
 
  fields:
    values: array[bars, float32]
  
  let 
    fft = getFft()
    w = 20.px
    radius = 90f.px
    length = 8f
  
  for i in 0..<bars:
    sys.values[i] = lerp(sys.values[i], fft[i].pow(0.6f), 35f * fau.delta)

    let rot = i / bars.float32 * pi2
    draw(fau.white, vec2l(rot, radius), size = vec2(sys.values[i].px * length, w), rotation = rot, align = daLeft, origin = vec2(0f, w / 2f), color = colorPink.mix(colorWhite, 0.5f))

makeSystem("drawTiles", []):
  let rad = 5
  for x in -rad..rad:
    for y in -rad..rad:
      let 
        absed = ((x + rad) + (y + rad) + turn).mod 5
        strength = (absed == 0).float32 * moveBeat
      draw("tile".patchConst, vec2(x, y), color = (%"ffffff").mix(colorBlue, strength).withA(0.4f), scl = vec2(1f - 0.11f * beat()))

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
  

launchFau("absurd")