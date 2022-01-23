type Unit* = ref object
  name*: string
  layers*: seq[proc(c: Unit)]

let
  unitMono* = Unit(name: "mono")
  unitOct* = Unit(name: "oct")
  unitZenith* = Unit(name: "zenith")
  unitQuad* = Unit(name: "quad")