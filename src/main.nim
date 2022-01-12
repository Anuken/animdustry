import ecs, fau/presets/[basic, effects], units, strformat, math

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
      scl: float32
      walkTime: float32
    
defineEffects:
  walk(lifetime = 0.8f):
    particlesLife(e.id, 10, e.pos, e.fin, 12f):
      fillCircle(pos, 4f * fout.powout(3f), color = %"6e7080")

sys("init", [Main]):
  init:
    discard newEntityWith(Input(), Pos(), GridPos(), UnitDraw(unit: unitQuad))

makeTimedSystem()

sys("input", [GridPos, Input, UnitDraw, Pos]):
  start:
    #TODO only one direction at a time?
    let vec = axisTap2(keyA, keyD, keyS, keyW) * 20f
  all:
    if keyEscape.tapped:
      quitApp()

    item.gridPos.x += vec.x.int
    item.gridPos.y += vec.y.int

    item.unitDraw.scl = item.unitDraw.scl.lerp(1f, 12f * fau.delta)

    if item.unitDraw.walkTime > 0:
      item.unitDraw.walkTime -= fau.delta * 9f

      if item.unitDraw.walkTime < 0f:
        item.unitDraw.walkTime = 0f

    if vec.zero.not:
      item.unitDraw.scl = 0.7f
      item.unitDraw.walkTime = 1f
      effectWalk(item.pos.vec2 + vec2(0f, 2f))

    if vec.x.abs > 0:
      item.unitDraw.side = vec.x < 0
    
sys("posLerp", [Pos, GridPos]):
  all:
    let a = 12f * fau.delta
    item.pos.x = lerp(item.pos.x, item.gridPos.x.float32, a)
    item.pos.y = lerp(item.pos.y, item.gridPos.y.float32, a)

sys("draw", [Main]):
  fields:
    buffer: Framebuffer
  init:
    sys.buffer = newFramebuffer()
  
  sys.buffer.clear(colorBlack)
  sys.buffer.resize(fau.size / scl)

  drawBuffer(sys.buffer)

  fau.cam.update(fau.size / scl, vec2())
  fau.cam.use()

makeEffectsSystem()

sys("drawUnit", [Pos, UnitDraw]):
  all:
    draw(
      (&"unit-{item.unitDraw.unit.name}").patch, 
      item.pos.vec2 + vec2(0f, item.unitDraw.walkTime.powout(2f).slope * 5f), 
      scl = vec2(-item.unitDraw.side.sign * (1f + (1f - item.unitDraw.scl)), item.unitDraw.scl), 
      align = daBot
    )

sys("endDraw", [Main]):
  drawBufferScreen() #for recorder
  sysDraw.buffer.blit()

launchFau("Yes")