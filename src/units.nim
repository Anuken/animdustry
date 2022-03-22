import tables, core

type Unit* = ref object
  name*: string
  title*: string
  subtitle*: string
  layers*: seq[proc(unit: Unit, pos: Vec2) {.nimcall.}]
  textures*: Table[string, Texture]

  #UI state (ugh)
  wasOver*: bool
  fade*: float32
  jump*: float32
  jumping*: bool
  clickTime*: float32

proc getTexture*(unit: Unit, name: string): Texture =
  ## Loads a unit texture from the textures/ folder. Result is cached. Crashes if the texture isn't found!
  if not unit.textures.hasKey(name):
    let tex = loadTextureAsset("textures/" & unit.name & name & ".png")
    tex.filter = tfLinear
    unit.textures[name] = tex
    return tex
  return unit.textures[name]

let
  unitBoulder* = Unit(name: "boulder")

  unitAlpha* = Unit(name: "alpha")
  unitMono* = Unit(
    name: "mono",
    title: "Mono",
    subtitle: "insert subtitle here"
  )
  unitCrawler* = Unit(name: "crawler")
  unitOct* = Unit(name: "oct")
  unitZenith* = Unit(name: "zenith")
  unitQuad* = Unit(name: "quad")
  unitOxynoe* = Unit(name: "oxynoe")
  unitSei* = Unit(name: "sei")

  allUnits* = [unitBoulder, unitAlpha, unitMono, unitCrawler, unitOct, unitZenith, unitQuad, unitOxynoe, unitSei]