import ecs, tables

type Beatmap* = ref object
  name*: string
  songName*: string
  #draws backgrounds with the pixelation buffer
  drawPixel*: proc()
  #draws non-pixelated background (tiles)
  draw*: proc()
  #creates patterns
  update*: proc()
  #used for conveyors and other objects fading in
  fadeColor*: Color
  #music track to use
  sound*: Sound
  #bpm for the music track
  bpm*: float
  #in seconds
  beatOffset*: float
  #max hits taken in this map before game over
  maxHits*: int
  #can be null! this is pixelated
  preview*: Framebuffer
  #amount of copper that you get on completing this map with perfect score (0 = default)
  copperAmount*: int

type Unit* = ref object
  name*: string
  title*: string
  subtitle*: string
  #displayed in bottom right info
  ability*: string
  #number to display in reload bar
  abilityReload*: int
  #called every move (optional)
  abilityProc*: proc(unit: EntityRef, moves: int)
  #draw the unit in the splash screen
  draw*: proc(unit: Unit, pos: Vec2) {.nimcall.}
  #cached textures
  textures*: Table[string, Texture]
  #true for boulder
  unmoving*: bool
  #true for "nothing"
  unobtainable*: bool
  #if true, this unit does not show up in the list of units unless unlocked
  hidden*: bool

  #UI state (ugh)
  wasOver*: bool
  fade*: float32
  jump*: float32
  jumping*: bool
  clickTime*: float32

type Gamemode* = enum
  #in game intro headphones screen
  gmIntro,
  #credits screen off of the menu
  gmCredits,
  #is in the main menu
  gmMenu,
  #TODO: is in settings menu (can still be playing a game in the background!)
  gmSettings,
  #currently in track
  gmPlaying,
  #temporarily paused with space/esc
  gmPaused,
  #ran out of health
  gmDead,
  #finished track, diisplaying stats
  gmFinished

type GameState* = object
  #may be nil, TODO make optional?
  map*: Beatmap
  #currently playing voice ID
  voice*: Voice
  #smoothed position of the music track in seconds
  secs*: float
  #last "discrete" music track position, internally used
  lastSecs*: float
  #smooth game time, may not necessarily match seconds. visuals only!
  time*: float32
  #last known player position
  playerPos*: Vec2i
  #Raw beat calculated based on music position
  rawBeat*: float
  #Beat calculated as countdown after a music beat happens. Smoother, but less precise.
  moveBeat*: float32
  #if true, a new turn was just fired this rame
  newTurn*: bool
  #snaps to 1 when player is hit for health animation
  hitTime*: float32
  #snaps to 1 when player is healed
  healTime*: float32
  #points awarded based on various events
  points*: int
  #beats that have passed total
  turn*: int
  copperReceived*: int
  hits*: int
  totalHits*: int
  misses*: int
  beatStats*: string

#Persistent user data.
type SaveState* = object
  #true if intro is complete
  introDone*: bool
  #all units that the player has collected (should be unique)
  units*: seq[Unit]
  #"gambling tokens"
  copper*: int
  #how many times the player has gambled
  rolls*: int
  #map high scores by map index (0 = no completion)
  scores*: seq[int]
  #last unit switched to - can be nil!
  lastUnit*: Unit
  #duplicate count by unit name
  duplicates*: Table[string, int]

#Persistent user settings.
type Settings* = object
  #audio latency in ms
  audioLatency*: float32
  #needs to be update on the audio end after loading
  globalVolume*: float32
  #whether to use gamepads on mobile
  gamepad*: bool
  #whether the mobile gamepad is on the left
  gamepadLeft*: bool
  #whether to show FPS on-screen (debugging only)
  showFps*: bool