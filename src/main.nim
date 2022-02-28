import ecs, fau/presets/[basic, effects], units, strformat, math

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
const scl = 4f

var 
  trackDefault, trackEva, trackLis, trackRiser: MusicTrack

  musicState = MusicState()

register(defaultComponentOptions):
  type 
    Input = object
  
    GridPos = object
      vec: Vec2i
    
    UnitDraw = object
      unit: Unit
      side: bool
      scl: float32
      walkTime: float32
    
defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 12f):
      fillCircle(pos, 4f * fout.powout(3f), color = %"6e7080")

template makeUnit(pos: Vec2i, aunit: Unit) =
  discard newEntityWith(Input(), Pos(vec: pos.vec2), GridPos(vec: pos), UnitDraw(unit: aunit))

template reset() =
  sysAll.clear()

  makeUnit(vec2i(), unitQuad)
  makeUnit(vec2i(-1, 0) * 20, unitOct)
  makeUnit(vec2i(1, 0) * 20, unitZenith)

proc beat(): float32 = musicState.beat

makeSystem("init", []):
  init:
    enableSoundVisualization()
    trackDefault = MusicTrack(sound: musicMerry, bpm: 125f, beatOffset: -40.0 / 1000.0)
    trackEva = MusicTrack(sound: musicEva, bpm: 50f, beatOffset: -160.0 / 1000.0)
    trackLis = MusicTrack(sound: musicLis, bpm: 113f, beatOffset: 0f / 1000f)
    trackRiser = MusicTrack(sound: musicRiser, bpm: 140f, beatOffset: 0f / 1000f)
    musicState.track = trackDefault

    reset()

makeSystem("all", [Pos]): discard

makeSystem("updateMusic", []):
  fields:
    lastPos: float
  
  if musicState.voice.valid and musicState.voice.playing:
    let beatSpacing = 1.0 / (musicState.track.bpm / 60.0)

    musicState.secs = musicState.voice.streamPos + musicState.track.beatOffset

    let 
      prevBeat = musicState.beatCount
      nextBeat = int(musicState.secs / beatSpacing)

    musicState.beatChanged = nextBeat != musicState.beatCount
    musicState.beatCount = nextBeat
    musicState.beat = (1.0 - ((musicState.secs mod beatSpacing) / beatSpacing)).float32
  elif not musicState.voice.valid:
    #TODO don't want to hear this
    musicState.voice = musicState.track.sound.play(volume = 0f)
    musicState.voice.seek(18.0)

makeTimedSystem()

makeSystem("input", [GridPos, Input, UnitDraw, Pos]):
  start:
    #TODO only one direction at a time?
    let vec = axis2(keyA, keyD, keyS, keyW) * 20f * musicState.beatChanged.float32
  all:
    if keyEscape.tapped:
      quitApp()

    item.gridPos.vec += vec.vec2i

    item.unitDraw.scl = item.unitDraw.scl.lerp(1f, 12f * fau.delta)

    if item.unitDraw.walkTime > 0:
      item.unitDraw.walkTime -= fau.delta * 9f

      if item.unitDraw.walkTime < 0f:
        item.unitDraw.walkTime = 0f

    if vec.zero.not:
      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec + vec2(0f, 2f))

    if vec.x.abs > 0:
      item.unitDraw.side = vec.x < 0
    
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
  sys.buffer.resize(fau.size / scl)

  #drawBuffer(sys.buffer)

  fau.cam.update(fau.size / scl, vec2())
  fau.cam.use()

makeSystem("drawBackground", []):
  poly(vec2(), 4, 45f + 15f * (musicState.beatCount mod 4).float32, 0f.rad, stroke = 10f, color = (%"9bceff").withA(beat()))

makeSystem("drawTiles", []):
  let rad = 5
  let space = 20f
  for x in -rad..rad:
    for y in -rad..rad:
      draw("tile".patchConst, vec2(x, y) * space, color = (%"ffffff").withA(0.15f), scl = vec2(1f - 0.11f * beat()))

makeEffectsSystem()

makeSystem("drawUnit", [Pos, UnitDraw]):
  all:
    draw(
      (&"unit-{item.unitDraw.unit.name}").patch, 
      item.pos.vec + vec2(0f, item.unitDraw.walkTime.powout(2f).slope * 5f), 
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - beat().pow(1) * 0.13f), 
      align = daBot
    )

makeSystem("endDraw", []):
  drawBufferScreen()
  #sysDraw.buffer.blit()

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
  

launchFau("Yes")