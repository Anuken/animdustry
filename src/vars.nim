import ecs, types

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
  ingameModes = {gmPaused, gmPlaying, gmDead, gmFinished}

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
  inIntro: bool
  #fade time for first game launch
  introTime: float32
  #splash screen fade-in time
  splashTime: float32
  #when >0, the splash screen is in "reveal" mode
  splashRevealTime: float32
  #increments when paused
  pauseTime: float32
  #1 when score changes
  scoreTime: float32
  #increments while credits are shown
  creditsPan: float32
  #if true, score change was positive
  scorePositive: bool
  
  #transition time for fading between scenes
  #when fading out, this will reach 1, call fadeTarget, and the fade back from 1 to 0
  fadeTime: float32
  #proc that will handle the fade-in when it happens - can be nil!
  fadeTarget: proc()