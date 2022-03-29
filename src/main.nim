import ecs, fau/presets/[basic, effects], units, strformat, math, random, fau/g2/font, fau/g2/ui, fau/g2/bloom, macros, options, fau/assets, strutils, algorithm, sequtils, tables

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
  #max hits taken in this map before game over
  maxHits: int
  #can be null! this is pixelated
  preview: Framebuffer
  #amount of copper that you get on completing this map with perfect score (0 = default)
  copperAmount: int

type Gamemode = enum
  gmMenu,
  #currently in track
  gmPlaying,
  #temporarily paused with space/esc
  gmPaused,
  #ran out of health
  gmDead,
  #finished track, diisplaying stats
  gmFinished

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
  #snaps to 1 when player is hit for health animation
  hitTime: float32
  #snaps to 1 when player is healed
  healTime: float32
  #points awarded based on various events
  points: int
  #beats that have passed total
  turn: int
  copperReceived: int
  hits: int
  totalHits: int
  misses: int
  beatStats: string

#Persistent user data.
type SaveState = object
  #all units that the player has collected (should be unique)
  units: seq[Unit]
  #"gambling tokens"
  copper: int
  #how many times the player has gambled
  rolls: int
  #map high scores by map index (0 = no completion)
  scores: seq[int]
  #last unit switched to - can be nil!
  lastUnit: Unit
  #duplicate count by unit name
  duplicates: Table[string, int]

#TODO better viewport
const
  #pixels
  tileSize = 20f
  hitDuration = 0.6f
  noMusic = false
  mapSize = 6
  fftSize = 50
  copperForRoll = 10
  #copper received for first map completion
  completionCopper = 10
  defaultMapReward = 8
  colorAccent = %"ffd37f"
  colorUi = %"bfecf3"
  colorUiDark = %"57639a"
  colorHit =  %"ff584c"
  colorHeal = %"84f490"
  #time between character switches
  switchDelay = 0.5f
  transitionTime = 0.2f
  transitionPow = 1f

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
  explodeFrames: array[5, Patch]
  hitFrames: array[5, Patch]
  #currently shown unit in splash screen, null when no unit
  splashUnit: Option[Unit]
  #splash screen fade-in time
  splashTime: float32
  #when >0, the splash screen is in "reveal" mode
  splashRevealTime: float32
  #increments when paused
  pauseTime: float32
  #1 when score changes
  scoreTime: float32
  #if true, score change was positive
  scorePositive: bool
  
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
      justMoved: bool
      couldMove: bool
      lastMove: Vec2i
      fails: int
      moves: int
  
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
      space: int
    
    Scaled = object
      scl: float32
      time: float32
    
    DrawBullet = object
      rot: float32
      sprite: string
    
    DrawSpin = object
      sprite: string

    DrawSquish = object
      sprite: string

    DrawBounce = object
      sprite: string
      rotation: float32

    DrawLaser = object
      dir: Vec2i
    
    DrawDamageField = object

    Bounce = object
      count: int
    
    LeaveBullet = object
      life: int

    Turret = object
      dir: Vec2i
      reload: int
      reloadCounter: int

    Lifetime = object
      turns: int
    
    Deleting = object
      time: float32
    
    #can be hit by player attacks
    Destructible = object

    #block attacks for the player
    Wall = object
      health: int

    Snek = object
      turns: int
      produced: bool
      gen: int
      fade: float32
      len: int
    
    SpawnConveyors = object
      len: int
      diagonal: bool
      #TODO merge with diagonal
      alldir: bool
      dir: Vec2i
    
    SpawnEvery = object
      space: int
      offset: int
      spawn: SpawnConveyors
    
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
  
  explode(lifetime = 0.4f):
    draw(explodeFrames[(e.fin * explodeFrames.len).int.min(explodeFrames.high)], e.pos, color = (%"ffb954").mix(%"d86a4e", e.fin))

  explodeHeal(lifetime = 0.4f):
    draw(explodeFrames[(e.fin * explodeFrames.len).int.min(explodeFrames.high)], e.pos, color = colorWhite.mix(colorHeal, e.fin.powout(2f)))

  walkWave:
    poly(e.pos, 4, e.fin.powout(6f) * 1f + 4f.px, stroke = 5f.px, color = colorWhite.withA(e.fout * 0.8f), rotation = 45f.rad)
  
  songShow(lifetime = 4f):
    if state.map != nil:
      defaultFont.draw("Music: " & state.map.songName, fau.cam.view - rect(vec2(0f, 0.8f + e.fin.pow(7f)), vec2(0, 0f)), color = colorUi.withA(e.fout.powout(6f)), align = daTopLeft)
  
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
    draw("lancer2".patchConst, e.pos, rotation = e.rotation - 90f.rad, scl = vec2(state.moveBeat * 0.16f + min(e.fin.powout(3f), e.fout.powout(20f))), z = 3001f)
  
  warnBullet:
    #poly(e.pos, 4, e.fout.pow(2f) * 0.6f + 0.5f, stroke = 4f.px * e.fout + 2f.px, color = colorWhite, rotation = 45f.rad)
    draw("bullet".patchConst, e.pos, rotation = e.rotation, size = vec2(16f.px), mixColor = colorWhite, color = colorWhite.withA(e.fin))
  
  fail:
    draw("fail".patchConst, e.pos, color = colorWhite.withA(e.fout), scl = vec2(1f) + e.fout.pow(4f) * 0.6f)

#snap position to grid position
GridPos.onAdd:
  let pos = entity.fetch(Pos)
  if pos.valid:
    pos.vec = curComponent.vec.vec2

#unit textures dynamically loaded
preloadFolder("textures")

include saveio

#All passed systems will be paused when game state is not playing
macro makePaused(systems: varargs[untyped]): untyped =
  result = newStmtList()
  for sys in systems:
    result.add quote do:
      `sys`.paused = (mode != gmPlaying)

template zlayer(entity: untyped): float32 = 1000f - entity.pos.vec.y

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

onEcsBuilt:
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
    
    #start with first unit
    makeUnit(vec2i(), if save.lastUnit != nil: save.lastUnit else: save.units[0])

  proc playMap(next: Beatmap, offset = 0.0) =
    reset()

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

proc fading(): bool = fadeTarget != nil

proc beatSpacing(): float = 1.0 / (state.map.bpm / 60.0)
proc musicTime(): float = state.secs

proc highScore(map: Beatmap): int =
  let index = maps.find(map)
  return save.scores[index]

proc `highScore=`(map: Beatmap, value: int) =
  let index = maps.find(map)
  if save.scores[index] != value:
    save.scores[index] = value
    saveGame()

proc unlocked(map: Beatmap): bool =
  let index = maps.find(map)
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

    #not fps based
    fau.targetFps = 0

    when noMusic:
      setGlobalVolume(0f)
    enableSoundVisualization()

    createMaps()
    maps = @[map1, map2, map3, map4, map5]

    createUnits()

    loadGame()

    #must have at least one unit as a default
    if save.units.len == 0:
      save.units.add unitAlpha
    
    sortUnits()

    if save.lastUnit == nil or save.lastUnit == unitBoulder:
      save.lastUnit = unitAlpha

    #resize scores to hold all maps
    if save.scores.len < maps.len:
      save.scores.setLen(maps.len)
    
    #TODO remove
    when defined(debug):
      playMap(map5, 0.0)
      mode = gmPlaying
  
  #yeah this would probably work much better as a system group
  makePaused(
    sysUpdateMusic, sysDeleting, sysUpdateMap, sysPosLerp, sysInput, sysTimed, sysScaled, 
    sysLifetime, sysSnek, sysSpawnEvery, sysSpawnConveyors, sysTurretFollow, 
    sysTurretShoot, sysDamagePlayer, sysUpdateVelocity, sysKillOffscreen,
    sysUpdateBounce, sysLeaveBullet
  )

  if mode in {gmPlaying, gmPaused} and (keySpace.tapped or keyEscape.tapped):
    mode = if mode != gmPlaying: gmPlaying else: gmPaused
  
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
      #perfect amount of copper received if the player always moved and never missed / got hit; it is assumed they miss at least 2 at the start/end
      perfectPoints = state.map.sound.length * 60f / state.map.bpm - 2
      #multiplier based on hits taken
      healthMultiplier = if state.totalHits == 0: 2.0 else: 1.0
      #fraction that was actually obtained
      perfectFraction = (state.points / perfectPoints).min(1f)
      #final amount based on score
      resultAmount = 1 + (perfectFraction * maxCopper * healthMultiplier).int + (if state.map.highScore == 0: completionCopper else: 0)

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
        if unit != item.unitDraw.unit and i < switchKeys.len and switchKeys[i].tapped:
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
      vec = if musicTime() >= item.input.lastInputTime and item.unitDraw.unit.unmoving.not: axisTap2(keyA, keyD, KeyCode.keyS, keyW) + axisTap2(keyLeft, keyRight, keyDown, keyUp) else: vec2()
    
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
          state.hitTime = 1f
          deleteCurrent()
          soundHit.play()
          addPoints(-7)

          #do not actually deal damage (iframes)
          if other.input.hitTurn < state.turn - 1:
            state.hits.inc
            state.totalHits.inc
            other.input.hitTurn = state.turn
  
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

    for i in 0..<explodeFrames.len:
      explodeFrames[i] = patch("explode" & $i)
    
    for i in 0..<hitFrames.len:
      hitFrames[i] = patch("hit" & $i)

  #margin is currently 4, adjust as needed
  let camScl = (min(fau.size.x, fau.size.y) / ((mapSize * 2 + 1 + 4)))

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

makeSystem("scaled", [Scaled]):
  all:
    item.scaled.time += fau.delta

makeSystem("bounceVelocity", [Velocity, DrawBounce]):
  all:
    if item.velocity.vec != vec2i():
      item.drawBounce.rotation = item.drawBounce.rotation.alerp(item.velocity.vec.angle, 10f * fau.delta)

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

    draw(
      (&"unit-{item.unitDraw.unit.name}{suffix}").patch,
      item.pos.vec + vec2(0f, (item.unitDraw.walkTime.powout(2f).slope * 5f - 1f).px),
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl - (item.unitDraw.beatScl) * 0.16f), 
      align = daBot,
      mixColor = colorWhite.withA(clamp(item.unitDraw.hitTime - 0.6f)).mix(colorAccent, item.unitDraw.switchTime.max(0f)),
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

makeSystem("drawUI", []):
  fields:
    #epic hardcoded array size (it really doesn't get any better than this)
    levelFade: array[32, float32]
    unitFade: array[32, float32]
    glowPatch: Patch9
  init:
    sys.glowPatch = "glow".patch9

  drawFlush()

  if state.hitTime > 0:
    state.hitTime -= fau.delta / 0.4f
    state.hitTime = state.hitTime.max(0f)

  if state.healTime > 0:
    state.healTime -= fau.delta / 0.4f
    state.healTime = state.healTime.max(0f)

  if mode != gmPlaying and mode != gmMenu:
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
    elif mode == gmFinished:
      let hitText = if state.totalHits == 0: "\nno hits! (200% reward)" else: ""
      defaultFont.draw(&"[ level complete! ]\nfinal score: {state.points}{hitText}", vec2(0f, if state.totalHits == 0: 1.25f else: 0.75f), scale = fontSize, color = colorUi)

      draw("copper".patchConst, vec2(-0.6f, -0.4f), scl = vec2(fontSize / fau.pixelScl), mixcolor = colorWhite.withA(1f - pauseTime))
      defaultFont.draw(&" +{state.copperReceived}", vec2(0f, -0.35f), align = daLeft, scale = fontSize, color = %"d99d73")

      buttonPos.y -= 1.1f
    elif mode == gmDead:
      defaultFont.draw(&"[ level failed! ]", vec2(0f, 0.5f), scale = fontSize, color = colorHit)
      buttonPos.y -= 1.3f

      if button(rectCenter(buttonPos + vec2(0f, 1.2f), 3f, 1f), "Retry"):
        let map = state.map
        capture map:
          safeTransition:
            reset()
            playMap(map)
            mode = gmPlaying

    if button(rectCenter(buttonPos, 3f, 1f), "Menu"):
      safeTransition:
        reset()
        mode = gmMenu
    
    #flash screen animation after winning
    if mode == gmFinished:
      draw(fau.white, fau.cam.pos, size = fau.cam.size, color = colorWhite.withA((1f - pauseTime).pow(4f)))
      poly(vec2(), 4, midrad + (1f - pauseTime).pow(4f) * 5f, stroke = (1f - pauseTime) * 9.px, color = colorWhite)
    elif mode == gmDead:
      draw(fau.white, fau.cam.pos, size = fau.cam.size, color = colorHit.withA((1f - pauseTime).pow(4f)))
      poly(vec2(), 4, midrad + (1f - pauseTime).pow(4f) * 5f, stroke = (1f - pauseTime) * 9.px, color = colorHit)

  if mode != gmMenu:
    #draw debug text
    when defined(debug):
      defaultFont.draw(&"{state.turn} | {state.beatStats} | {musicTime().int div 60}:{(musicTime().int mod 60):02} | {fau.fps} fps", fau.cam.view, align = daBot)

    if scoreTime > 0:
      scoreTime -= fau.delta / 0.5f
    
    scoreTime = scoreTime.max(0f)

    defaultFont.draw(&"[ {state.points:04} ]", fau.cam.view.grow(vec2(-4f.px, 0f)), align = daTopLeft, color = colorWhite.mix(if scorePositive: colorAccent else: colorHit, scoreTime.pow(3f)))

    let
      progSize = vec2(22f.px, 0f)
      progress = state.secs / state.map.sound.length
      healthPos = fau.cam.viewport.topRight - vec2(0.75f)

    draw("progress".patchConst, vec2(0f, fau.cam.size.y / 2f - 0.4f))
    draw("progress-tick".patchConst, vec2(0f, fau.cam.size.y / 2f - 0.4f) + progSize * (progress - 0.5f) * 2f, color = colorUiDark)

    draw("health".patchConst, healthPos, scl = vec2(1f + state.hitTime * 0.2f), color = colorUi.mix(colorHeal, state.healTime).mix(colorHit, state.hitTime))
    defaultFont.draw($health(), healthPos + vec2(0f, 1f.px), color = colorWhite.mix(colorHeal, state.healTime).mix(colorHit, state.hitTime))

    let screen = fau.cam.viewport
    if sysInput.groups.len > 0:
      let player = sysInput.groups[0]

      for i, unit in save.units:
        let 
          pos = screen.xy + vec2(i.float32 * 0.8f, 0f)
          current = player.unitDraw.unit == unit
        draw(patch(&"unit-{unit.name}"), pos, align = daBotLeft, mixColor = if current: rgb(0.1f).withA(0.8f) else: colorClear, scl = vec2(0.75f))
        defaultFont.draw($(i + 1), rect(pos + vec2(4f.px, -2f.px), 1f.vec2), align = daBotLeft, color = if current: colorGray else: colorWhite)
  elif splashUnit.isSome and splashRevealTime > 0f: #draw splash unit reveal animation
    splashRevealTime -= fau.delta / 3f

    let
      inv = 1f - splashRevealTime
      unit = splashUnit.get
      baseScl = inv.pow(14f)
      scl = vec2(0.17f) * baseScl
    
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
    splashTime += fau.delta / 4f
    splashTime = min(splashTime, 1f)

    let
      unit = splashUnit.get
      pos = vec2(0f, -5f.px)
      screen = fau.cam.viewport
      titleBounds = screen.grow(-0.4f)
      subtitleBounds = screen.grow(-2.2f)
      abilityW = screen.w / 4f
      abilityBounds = rect(screen.x + (screen.w - abilityW), screen.y, abilityW, screen.h).grow(-0.4f)
      fullPatch = patch(&"{unit.name}-real")

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
      color = colorWhite,#.mix(%"ffcc74", fau.time.sin(0.5f, 0.5f).abs), 
      align = daTop, 
      modifier = (proc(index: int, offset: var fmath.Vec2, color: var Color, draw: var bool) =
        offset.x += ((index + 0.5f) - unit.title.len/2f) * 15f.px * splashTime.powout(3f)
        #offset.y -= si.max(0f) * 5f.px
        #color = colorWhite.mix(%"84f490", si * 0.8f)
      )
    )

    #draw non-waifu sprite
    if fullPatch.exists:
      for i in signs():
        draw(fullPatch, vec2(screen.centerX + unit.title.len/2f * (0.9f + splashTime.powout(3f) * 0.9f) * i.float32, screen.top - 0.75f))

    defaultFont.draw(unit.subtitle, subtitleBounds, color = rgb(0.8f), align = daTop, scale = 0.75f.px)

    if unit.ability.len > 0:
      defaultFont.draw(unit.ability, abilityBounds, color = rgb(0.7f), align = daBotRight, scale = 0.75f.px)

    if button(rectCenter(screen.x + 2f, screen.y + 1f, 3f, 1f), "Back") or keyEscape.tapped:
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
    text(rectCenter(statsBounds.centerX + 4f, buttonY, 3f, 1f), &"{save.copper} / {copperForRoll}", align = daLeft, color = if save.copper >= copperForRoll: colorWhite else: %"ff4843")
    draw("copper".patchConst, vec2(statsBounds.centerX + 2f, buttonY))

    var bstyle = defaultButtonStyle
    bstyle.textUpColor = (%"ffda8c").mix(colorWhite, fau.time.sin(0.23f, 1f))

    for i, unit in allUnits:
      let
        unlock = unit.unlocked #TODO uncomment once testing is over
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
    
    #TODO remove
    when defined(debug):
      save.copper = 10

    #must be after units so shown stuff doesn't disappear
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

      splashRevealTime = 1f
      showSplashUnit(unit)
    
    #outline around everything
    lineRect(statsBounds, stroke = 2f.px, color = colorUi, margin = 1f.px)

    #draw map select
    for i in countdown(maps.len - 1, 0):
      let 
        map = maps[i]
        unlocked = map.unlocked
      assert map.preview != nil

      var
        offset = sys.levelFade[i]
        r = rect(bounds.x + sliced * i.float32, bounds.y, sliced, bounds.h)
        over = r.contains(mouse)

      sys.levelFade[i] = offset.lerp(over.float32, fau.delta * 20f)
      
      #only expands after bounds check to prevent weird input
      if i != maps.len - 1 and unlocked: #do not expand last map, no space for it
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

launchFau(initParams(title = "absurd"))