import tables, core, random, polymorph

type Unit* = ref object
  name*: string
  title*: string
  subtitle*: string
  ability*: string
  abilityProc*: proc(unit: EntityRef)
  draw*: proc(unit: Unit, pos: Vec2) {.nimcall.}
  textures*: Table[string, Texture]
  unmoving*: bool

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
    unmoving: true
  )
  unitAlpha* = Unit(
    name: "alpha",
    title: "-ALPHA-",
    subtitle: "first"
  )
  unitMono* = Unit(
    name: "mono",
    title: "-MONO-",
    subtitle: "the gatherer"
  )
  unitCrawler* = Unit(
    name: "crawler",
    title: "-CRAWLER-",
    subtitle: ""
  )
  unitOct* = Unit(
    name: "oct",
    title: "-OCT-",
    subtitle: ""
  )
  unitZenith* = Unit(
    name: "zenith",
    title: "-ZENITH-",
    subtitle: "gaming"
  )
  unitQuad* = Unit(
    name: "quad",
    title: "-QUAD-",
    subtitle: "the \"support\" has arrived"
  )
  unitOxynoe* = Unit(
    name: "oxynoe",
    title: "-OXYNOE-",
    subtitle: ""
  )
  unitSei* = Unit(
    name: "sei",
    title: "-SEI-",
    subtitle: ""
  )

  allUnits* = [unitBoulder, unitAlpha, unitMono, unitCrawler, unitOct, unitZenith, unitQuad, unitOxynoe, unitSei]

proc rollUnit*(): Unit =
  #boulder has a much higher chance to be selected, because it's useless
  if chance(0.33f):
    return unitBoulder

  return sample(allUnits)