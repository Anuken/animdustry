import ecs, fau/presets/[basic, effects], units, strformat

static: echo staticExec("faupack -p:../assets-raw/sprites -o:../assets/atlas --max:2048")

#TODO better system
const scl = 4f

registerComponents(defaultComponentOptions):
  type 
    Input = object
  
    GridPos = object
      x, y: int
    
    UnitDraw = object
      unit: Unit
      side: bool
    
sys("init", [Main]):
  init:
    discard newEntityWith(Input(), Pos(), UnitDraw(unit: unitQuad))

sys("input", [Pos, Input, UnitDraw]):
  start:
    #TODO only one direction at a time?
    let vec = axisTap2(keyA, keyD, keyS, keyW) * 20f
  all:
    item.pos.x += vec.x
    item.pos.y += vec.y

    if vec.x.abs > 0:
      item.unitDraw.side = vec.x < 0

sys("draw", [Main]):
  fau.cam.update(fau.size / scl, vec2())
  fau.cam.use()

sys("drawUnit", [Pos, UnitDraw]):
  all:
    draw((&"unit-{item.unitDraw.unit.name}").patch, item.pos.vec2, scl = vec2(-item.unitDraw.side.sign, 1f))

launchFau("Yes")