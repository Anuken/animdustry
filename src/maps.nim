import sugar

var
  map1, map2, map3, map4, map5: Beatmap

template bullet(pos: Vec2i, dir: Vec2i, tex = "") =
  discard newEntityWith(Scaled(scl: 1f), DrawBullet(sprite: tex), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage())

template bulletsCorners() =
  let spacing = 2

  if turn mod spacing == 0:
    let corner = d4iedge[(turn div spacing) mod 4] * mapSize

    for dir in d8():
      bullet(corner, dir)

template delayBullet(pos: Vec2i, dir: Vec2i, tex = "") =
  let 
    p = pos
    d = dir
  capture p, d:
    runDelay:
      bullet(p, d, tex)

template conveyor(pos: Vec2i, dir: Vec2i, length = 2) =
  discard newEntityWith(DrawConveyor(), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage(), Snek(len: length))

template bulletCircle(pos: Vec2i) =
  for dir in d8():
    bullet(pos, dir)

proc modSize(num: int): int =
  num.mod(mapSize * 2 + 1) - mapSize

template createMaps() =
  map1 = BeatMap(
    songName: "Aritus - For You",
    sound: musicAritusForYou,
    bpm: 126f,
    beatOffset: -80f / 1000f,
    fadeColor: colorPink.mix(colorWhite, 0.5f),
    drawPixel: (proc() =
      patStripes()
      patBeatSquare()
      patPetals()
    ),
    draw: (proc() =
      patTiles()
    ),
    update: (proc() =
      if state.newTurn:
        let turn = state.turn
        #make routers at first turn.
        #if turn == 1:
        #  for pos in d4edge():
        #    discard newEntityWith(Pos(), GridPos(vec: pos * mapSize), DrawRouter())

        #bulletsCorners()

        let space = 4

        template midRouter() =
          let 
            off = turn + 1
            routSpace = space * 2

          if (off + 1).mod(routSpace) == 0:
            effectWarn(vec2(), life = beatSpacing())

          if off mod(routSpace) == 0:
            discard newEntityWith(DrawRouter(), Pos(), GridPos(vec: vec2i()), Damage(), SpawnConveyors(len: 2, diagonal: (off.mod(routSpace * 2) == 0)), Lifetime(turns: 2))
        
        template moveRouter(offset: int) =
          let 
            off = turn + 1 - offset
            routSpace = space * 2
            x = (off div routSpace).mod(mapSize * 2 + 1) - mapSize
            pos = vec2i(x, 0)

          if (off + 1) mod(routSpace) == 0:
            effectWarn(pos.vec2, life = beatSpacing())
            runDelay:
              discard newEntityWith(DrawRouter(), Pos(), GridPos(vec: pos), Damage(), SpawnConveyors(len: 3, diagonal: (off.mod(routSpace * 2) == 0)), Lifetime(turns: 2))
        
        template horizontalConveyors(len = 2) =
          if turn mod space == 0:
            let dir = (((turn div space).mod 2) == 0).signi
            for i in signsi():
              conveyor(vec2i(-mapSize * dir, ((turn div space).mod(mapSize + 1)) * i), vec2i(dir, 0), len)
        
        template vertConveyors() =
          if turn mod(space * 4) == 0:
            for i in signsi():
              conveyor(vec2i(mapSize - ((turn div (space * 4)) mod mapSize), mapSize) * i, vec2i(0, -i), 5)

        template vertConveyorsMore() =
          if turn mod(space) == 0:
            for i in signsi():
              conveyor(vec2i(mapSize - ((turn div (space)) mod mapSize) - 1, mapSize) * i, vec2i(0, -i), 2)

        template sideDuos() =
          if turn.mod(space * 8) == 0 and sysTurretShoot.groups.len == 0:
            let side = (turn.mod(space * 8 * 2) == 0).signi
            discard newEntityWith(Pos(), GridPos(vec: vec2i(-mapSize * side, 0)), DrawTurret(sprite: "duo"), Turret(reload: 4, dir: vec2i(side, 0)), Lifetime(turns: space * 4))
            
        template topDuos() =
          if turn.mod(space * 8) == 0 and sysTurretShoot.groups.len == 0:
            for side in signsi():
              discard newEntityWith(Pos(), GridPos(vec: vec2i(0, -mapSize * side)), DrawTurret(sprite: "duo"), Turret(reload: 4, dir: vec2i(0, side)), Lifetime(turns: space * 4))
        
        template spiral() =
          let s = space
          let t = turn + 1
          if t.mod(s) == 0:
            let m = t.mod(mapSize * 2 + 1) - mapSize
            for i in 0..3:
              let v = vec2(mapSize, m).rotate(i * 90f.rad).vec2i
              effectWarn(v.vec2)
              capture v, i:
                runDelay:
                  conveyor(v, d4i[(i + 2).mod(4)], 1)

        template horStripes(offset: int) =
          let t = turn - offset
          let s = 2
          if t.mod(s) == 0:
            let 
              side = ((t mod (s * 2)) == 0).signi
              y = (t div s).mod(mapSize * 2 + 1) - mapSize
            
            conveyor(vec2i(-mapSize * side, y), vec2i(side, 0), 6)

        if turn in 0..35:
          horizontalConveyors()
        
        if turn in 35..55:
          midRouter()

        if turn in 35..85:
          sideDuos()
        
        if turn in 60..80:
          vertConveyors()
        
        #"you"
        let next = turn + 1
        if next in [68, 84, 148, 164, 228, 236, 260, 268, 292, 300, 324, 332, 356, 372, 388, 397, 420, 430]:
          for pos in d4():
            effectWarn((pos * mapSize).vec2, life = beatSpacing())
          runDelay:
            for pos in d4():
              for dir in d8():
                bullet(pos * mapSize, dir, "bullet-pink")

        if turn == 35:
          for i in signsi():
            conveyor(vec2i(mapSize, mapSize) * i, vec2i(0, -i), 5)
        
        #bullet walls
        if turn in 91..116:
          let s = 4
          if turn mod s == 0:
            let side = (turn div s).mod(2) == 1
            let r = (if side: 0..<3 else: 3..mapSize)
            for val in r:
              for s in signsi():
                bullet(vec2i(mapSize, val * s), vec2i(-1, 0), "bullet-pink")
        
        if turn in 117..164:
          horizontalConveyors(3)
        
        if turn in 117..180:
          topDuos()
        
        if turn in 171..223:
          horStripes(172)
        
        if turn in 225..290:
          moveRouter(225)
        
        if turn == 290:
          for pos in d4edge():
            effectWarn((pos * mapSize).vec2, life = beatSpacing())
          runDelay:
            for pos in d4edge():
              for dir in d8():
                bullet(pos * mapSize, dir, "bullet-pink")
        
        if turn in 291..360:
          vertConveyorsMore()

        if turn in 291..372:
          topDuos()
        
        if turn in 372..420:
          spiral()
        
        if turn in 420..437:
          midRouter()
    )
  )

  #TODO
  map2 = Beatmap(
    songName: "PYC - Stoplight",
    sound: musicStoplight,
    bpm: 85f,
    beatOffset: 0f / 1000f,
    fadeColor: %"985eb9",
    drawPixel: (proc() =
      patBackground(%"2b174d")
      patFadeShapes(%"4b2362")

      patStars(%"b3739a", %"e8c8b2")

      #patTris(%"8b4195")

      patClouds(%"653075")
      patBeatAlt(%"bf96eb")
      #patFft()
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      if state.newTurn:
        let turn = state.turn
        #33: "wicked"
        #beat on odd turns begins here

        template sideConveyors() =
          let space = 8

          if (turn mod space) == 0:
            let side = (turn.mod(space * 2) == 0).int
            for i in 0..mapSize:
              conveyor(vec2i(i - side * mapSize, -mapSize), vec2i(0, 1), 5)
        
        template sideBullets() =
          let space = 6
          let bspace = 3
          if turn mod space == 0:
            let side = (turn.mod(space * 2) == 0).int
            for i in -mapSize..mapSize:
              if (i + turn div space).emod(bspace) == 0:
                for side in signsi():
                  effectWarnBullet(vec2i(side * mapSize, i).vec2, life = beatSpacing())
                  delayBullet(vec2i(side * mapSize, i), vec2i(-side, 0))

        #if turn in 0..32:
        sideConveyors()

        if turn >= 30:
          sideBullets()
    )
  )

  #TODO
  map3 = Beatmap(
    songName: "Keptor's Room - Bright 79", # (from Topaze Club)?
    sound: musicBright79,
    bpm: 127f,
    beatOffset: -80f / 1000f,
    fadeColor: %"205359",
    drawPixel: (proc() =
      patBackground(%"205359")
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      discard
    )
  )

  #TODO
  map4 = Beatmap(
    songName: "Aritus - Pina Colada II",
    sound: musicPinaColada,
    bpm: 125f,
    beatOffset: -240f / 1000f,
    fadeColor: %"7e44e2",
    drawPixel: (proc() =
      patBackground(%"7e44e2")
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      discard
    )
  )

  #TODO
  map5 = Beatmap(
    songName: "ADRIANWAVE - Peach Beach",
    sound: musicPeachBeach,
    bpm: 121f,
    beatOffset: 0f / 1000f,
    fadeColor: %"e586cb",
    drawPixel: (proc() =
      patBackground(%"e586cb")
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      discard
    )
  )

#the old patterns for crosses and routers and stuff
#[
          let off = turn + 1

          #warning for router spawn?
          if (off + 1) mod space == 0:
            effectWarn(vec2(), life = beatSpacing())

          if off mod space == 0:
            discard newEntityWith(DrawRouter(), Pos(), GridPos(vec: vec2i()), Damage(), SpawnConveyors(len: 2, diagonal: (turn.mod(space * 2) == 0)), Lifetime(turns: 2))
            
          if off mod (space*2) == 0:
            let cor = (off / (space * 2)).mod(mapSize * 2 + 1)
            var i = 0
            for corner in d4edge():
              discard newEntityWith(DrawRouter(), Pos(), GridPos(vec: corner * mapSize + vec2l(i * 90f.rad + 180f.rad, cor).vec2i), Damage(), SpawnConveyors(len: 3), Lifetime(turns: 2))
              i.inc
]#