import ecs, types, fau/g2/[font, ui], std/[options, deques]

const
  #pixels
  tileSize* = 20f

  hitDuration* = 0.6f
  noMusic* = false
  mapSize* = 6
  fftSize* = 50
  #copper needed for 1 gamble
  copperForRoll* = 0
  #copper received for first map completion
  completionCopper* = 999999
  defaultMapReward* = 8

  colorAccent* = %"ffd37f"
  colorUi* = %"bfecf3"
  colorUiDark* = %"57639a"
  colorHit* =  %"ff584c"
  colorHeal* = %"84f490"

  #time between character switches
  switchDelay* = 0.5f
  transitionTime* = 0.2f
  transitionPow* = 1f
  ingameModes* = {gmPaused, gmPlaying, gmDead, gmFinished}

var
  allMaps*: seq[Beatmap]
  #Settings state.
  settings*: Settings = Settings(globalVolume: 1f)
  #Per-map state. Resets between games.
  state* = GameState()
  #Persistent save state.
  save* = SaveState()
  mode* = gmMenu
  
  fftValues*: array[fftSize, float32]
  titleFont*: Font

  gamepadButtonStyle*: ButtonStyle

  #UI state section

  #D-pad for mobile state
  mobilePad*: Vec2
  mobileUnitSwitch*: int = -1

  #frames for effects (bad)
  smokeFrames*: array[6, Patch]
  explodeFrames*: array[5, Patch]
  hitFrames*: array[5, Patch]

  #currently shown unit in splash screen, null when no unit
  splashUnit*: Option[Unit]
  inIntro*: bool
  #fade time for first game launch
  introTime*: float32
  #splash screen fade-in time
  splashTime*: float32
  #when >0, the splash screen is in "reveal" mode
  splashRevealTime*: float32
  #increments when paused
  pauseTime*: float32
  #1 when score changes
  scoreTime*: float32
  #increments while credits are shown
  creditsPan*: float32
  #if true, score change was positive
  scorePositive*: bool

  #><
  dizzyTime*: float32
  #for smoothing
  dizzyVec*: Vec2
  #angles
  dizzySamples* = initDeque[float32]()
  dizzyCheckTime*: float32
  
  #transition time for fading between scenes
  #when fading out, this will reach 1, call fadeTarget, and the fade back from 1 to 0
  fadeTime*: float32
  #proc that will handle the fade-in when it happens - can be nil!
  fadeTarget*: proc()

let
  unitBoulder* = Unit(
    name: "boulder",
    title: "-BOULDER-",
    subtitle: "it's just a rock",
    unmoving: true,
    ability: "utterly useless",
    hidden: true
  )
  unitAlpha* = Unit(
    name: "alpha",
    title: "-ALPHA-",
    subtitle: "the first of many",
    ability: "creates a wall every 10 moves",
    abilityReload: 10
  )
  unitMono* = Unit(
    name: "mono",
    title: "-MONO-",
    subtitle: "the gatherer",
    ability: "earns one extra point every 4 moves",
  )
  unitOct* = Unit(
    name: "oct",
    title: "-OCT-",
    subtitle: "the protector",
    ability: "creates a shield every 30 moves",
    #too long, not important
    #abilityReload: 30
  )
  unitCrawler* = Unit(
    name: "crawler",
    title: "-CRAWLER-",
    subtitle: "boom",
    ability: "destroys 4 adjacent blocks every 4 moves",
    abilityReload: 4
  )
  unitZenith* = Unit(
    name: "zenith",
    title: "-ZENITH-",
    subtitle: "gaming",
    ability: "destroys the next 4 blocks in a line every 4 moves",
    abilityReload: 4
  )
  unitQuad* = Unit(
    name: "quad",
    title: "-QUAD-",
    subtitle: "the \"support\" has arrived",
    ability: "destroys 8 adjacent blocks every 6 moves",
    abilityReload: 6
  )
  unitOxynoe* = Unit(
    name: "oxynoe",
    title: "-OXYNICE-",
    subtitle: "she nice-",
    ability: "destroys alternating adjacent blocks every other move",
    abilityReload: 2
  )
  unitSei* = Unit(
    name: "sei",
    title: "-SEI-",
    subtitle: "crossed out",
    ability: "destroys blocks in a diagonal cross every 4 moves",
    abilityReload: 4
  )
  unitNothing* = Unit(
    name: "nothing",
    title: "-NOTHING-",
    subtitle: "you've been trolled",
    ability: "the gacha game experience",
    unobtainable: true
  )
  unitRonaldo* = Unit(
    name: "ronaldo",
    title: "-RONALDO-",
    subtitle: "Manchester United",
    ability: "SIUUU",
    abilityReload: 5
  )

  allUnits* = [unitRonaldo, unitAlpha, unitMono, unitOct, unitCrawler, unitZenith, unitQuad, unitOxynoe, unitSei, unitBoulder]