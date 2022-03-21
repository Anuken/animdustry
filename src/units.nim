type Unit* = ref object
  name*: string
  title*: string
  subtitle*: string
  layers*: seq[proc(c: Unit)]

let
  unitMono* = Unit(name: "mono")
  unitOct* = Unit(name: "oct")
  unitZenith* = Unit(name: "zenith")
  unitQuad* = Unit(name: "quad")
  allUnits* = [unitMono, unitOct, unitZenith, unitQuad]