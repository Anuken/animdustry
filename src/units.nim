type Unit* = ref object
  name*: string
  layers*: seq[proc(c: Unit)]

let
  unitMono* = Unit(name: "mono")
  unitQuad* = Unit(name: "quad")