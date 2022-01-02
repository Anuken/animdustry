type Character* = ref object
  name*: string
  layers*: seq[proc(c: Character)]

let
  charMono* = Character(
    name: "mono"
  )