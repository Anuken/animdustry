import tables, core, random, polymorph

type Unit* = ref object
  name*: string
  title*: string
  subtitle*: string
  ability*: string
  abilityReload*: int
  abilityProc*: proc(unit: EntityRef, moves: int)
  draw*: proc(unit: Unit, pos: Vec2) {.nimcall.}
  textures*: Table[string, Texture]
  unmoving*: bool
  unobtainable*: bool

  #UI state (ugh)
  wasOver*: bool
  fade*: float32
  jump*: float32
  jumping*: bool
  clickTime*: float32

proc clearTextures*(unit: Unit) = unit.textures.clear()

proc getTexture*(unit: Unit, name: string = ""): Texture =
  ## Loads a unit texture from the textures/ folder. Result is cached. Crashes if the texture isn't found!
  if not unit.textures.hasKey(name):
    let tex = loadTextureAsset("textures/" & unit.name & name & ".png")
    tex.filter = tfLinear
    unit.textures[name] = tex
    return tex
  return unit.textures[name]

let
  unitBoulder* = Unit(
    name: "boulder",
    title: "-BOULDER-",
    subtitle: "it's just a rock",
    unmoving: true,
    ability: "utterly useless"
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
    #unimportant
    #abilityReload: 4
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
    title: "-OXYNOE-",
    subtitle: "as was foretold",
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
    subtitle: "you've been scammed",
    ability: "the gacha game experience",
    unobtainable: true
  )

  allUnits* = [unitAlpha, unitMono, unitOct, unitCrawler, unitZenith, unitQuad, unitOxynoe, unitSei, unitBoulder]

proc rollUnit*(): Unit =
  #very low chance, as it is annoying
  if chance(2f / 100f):
    return unitNothing

  #boulder has a much higher chance to be selected, because it's useless
  if chance(0.4f):
    return unitBoulder

  #not all units; alpha and boulder are excluded
  return sample([unitMono, unitOct, unitCrawler, unitZenith, unitQuad, unitOxynoe, unitSei])