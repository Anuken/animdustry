import ecs, options, tables

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
  maxHits: int
  #can be null! this is pixelated
  preview*: Framebuffer
  #amount of copper that you get on completing this map with perfect score (0 = default)
  copperAmount*: int

type Gamemode* = enum
  #in game intro headphones screen
  gmIntro,
  #credits screen off of the menu
  gmCredits,
  #is in the main menu
  gmMenu,
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