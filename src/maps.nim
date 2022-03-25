import sugar

var
  map1, map2, map3, map4, map5: Beatmap

template bulletsCorners() =
  let spacing = 2

  if turn mod spacing == 0:
    let corner = d4iedge[(turn div spacing) mod 4] * mapSize

    for dir in d8():
      makeBullet(corner, dir)

template delayBullet(pos: Vec2i, dir: Vec2i, tex = "") =
  let 
    p = pos
    d = dir
  capture p, d:
    runDelay:
      makeBullet(p, d, tex)

template delayBulletWarn(pos: Vec2i, dir: Vec2i, tex = "") =
  delayBullet(pos, dir, tex)
  effectWarnBullet(pos.vec2, rot = dir.vec2.angle, life = beatSpacing())

template bulletCircle(pos: Vec2i, tex = "") =
  for dir in d8():
    makeBullet(pos, dir, tex)

proc modSize(num: int): int =
  num.mod(mapSize * 2 + 1) - mapSize

template createMaps() =
  map1 = BeatMap(
    songName: "Aritus - For You",
    sound: musicAritusForYou,
    bpm: 126f,
    beatOffset: -80f / 1000f,
    maxHits: 20,
    copperAmount: 25,
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
            makeRouter(vec2i(), diag = off.mod(routSpace * 2) == 0)
        
        template moveRouter(offset: int) =
          let 
            off = turn + 1 - offset
            routSpace = space * 2
            x = (off div routSpace).mod(mapSize * 2 + 1) - mapSize
            pos = vec2i(x, 0)

          if (off + 1) mod(routSpace) == 0:
            effectWarn(pos.vec2, life = beatSpacing())
            runDelay:
              makeRouter(pos, length = 3, diag = (off.mod(routSpace * 2) == 0))
        
        template horizontalConveyors(len = 2) =
          if turn mod space == 0:
            let dir = (((turn div space).mod 2) == 0).signi
            for i in signsi():
              makeConveyor(vec2i(-mapSize * dir, ((turn div space).mod(mapSize + 1)) * i), vec2i(dir, 0), len)
        
        template vertConveyors() =
          if turn mod(space * 4) == 0:
            for i in signsi():
              makeConveyor(vec2i(mapSize - ((turn div (space * 4)) mod mapSize), mapSize) * i, vec2i(0, -i), 5)

        template vertConveyorsMore() =
          if turn mod(space) == 0:
            for i in signsi():
              makeConveyor(vec2i(mapSize - ((turn div (space)) mod mapSize) - 1, mapSize) * i, vec2i(0, -i), 2)

        template sideDuos() =
          if turn.mod(space * 8) == 0 and sysTurretShoot.groups.len == 0:
            let side = (turn.mod(space * 8 * 2) == 0).signi
            makeTurret(vec2i(-mapSize * side, 0), vec2i(side, 0), 4, space * 4)
            
        template topDuos() =
          if turn.mod(space * 8) == 0 and sysTurretShoot.groups.len == 0:
            for side in signsi():
              makeTurret(vec2i(0, -mapSize * side), vec2i(0, side), 4, space * 4)
        
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
                  makeConveyor(v, d4i[(i + 2).mod(4)], 1)

        template horStripes(offset: int) =
          let t = turn - offset
          let s = 2
          if t.mod(s) == 0:
            let 
              side = ((t mod (s * 2)) == 0).signi
              y = (t div s).mod(mapSize * 2 + 1) - mapSize
            
            makeConveyor(vec2i(-mapSize * side, y), vec2i(side, 0), 6)

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
        if next in [68, 84, 148, 164, 228, 236, 260, 268, 292, 300, 324, 332, 356, 372, 388, 397, 420, 428]:
          for pos in d4():
            effectWarn((pos * mapSize).vec2, life = beatSpacing())
          runDelay:
            for pos in d4():
              for dir in d8():
                makeBullet(pos * mapSize, dir, "bullet-pink")

        if turn == 35:
          for i in signsi():
            makeConveyor(vec2i(mapSize, mapSize) * i, vec2i(0, -i), 5)
        
        #bullet walls
        if turn in 91..116:
          let s = 4
          if turn mod s == 0:
            let side = (turn div s).mod(2) == 1
            let r = (if side: 0..<3 else: 3..mapSize)
            for val in r:
              for s in signsi():
                makeBullet(vec2i(mapSize, val * s), vec2i(-1, 0), "bullet-pink")
        
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
                makeBullet(pos * mapSize, dir, "bullet-pink")
        
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
    maxHits: 15,
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
        #32: "wicked"
        #beat on odd turns begins here

        template sideConveyors =
          let space = 8

          if (turn mod space) == 0:
            let side = (turn.mod(space * 2) == 0).int
            for i in 0..mapSize:
              makeConveyor(vec2i(i - side * mapSize, -mapSize), vec2i(0, 1), 5)
        
        template sideBullets =
          let space = 6
          let bspace = 3
          if turn mod space == 0:
            let side = (turn.mod(space * 2) == 0).int
            for i in -mapSize..mapSize:
              if (i + turn div space).emod(bspace) == 0:
                for side in signsi():
                  effectWarnBullet(vec2i(side * mapSize, i).vec2, life = beatSpacing())
                  delayBullet(vec2i(side * mapSize, i), vec2i(-side, 0), "bullet-purple")
        
        template timeStrikes =
          let space = 4

          if turn mod space == 0:
            let pos = state.playerPos
            for i in 0..3:
              capture i, pos:
                runDelayi(i):
                  effectStrikeWave(pos.vec2, rot = i.float32, life = beatSpacing())
                  if i == 3:
                    bulletCircle(pos, "bullet-purple")
        
        template topDownConveyors =
          let space = 8
          if turn mod space == 0:
            let side = (turn.mod(space * 2) == 0).int
            for y in signsi():
              for i in -mapSize..mapSize:
                if (i + (y == 1).int).emod(2) == 0:
                  makeConveyor(vec2i(i, y * mapSize), vec2i(0, -y), 5)
        
        #single event
        template sideWeave =
          for x in signsi():
            for i in -mapSize..mapSize:
              if (i + (x == 1).int).emod(2) == 0:
                makeConveyor(vec2i(x * mapSize, i), vec2i(-x, 0), 1)

        template sideSorters =
          let space = 4
          if turn mod space == 0:
            makeSorter(vec2i(mapSize, 0), vec2i(-1, 0))
        
        template rightConveyors =
          let space = 2
          if turn mod space == 0:
            for i in signsi():
              makeConveyor(vec2i(mapSize, mapSize * i), vec2i(0, -i), length = 1)
        
        template midBullets = 
          for dir in d8():
            delayBulletWarn(dir * mapSize, -dir, "bullet-purple")
        
        template quadDuos =
          for dir in d4():
            makeTurret(dir * mapSize, -dir, life = 26)

        template crossRouters =
          let 
            off = turn + 1
            space = 4

          #warning for router spawn?
          if (off + 1) mod space == 0:
            effectWarn(vec2(), life = beatSpacing())

          if off mod space == 0:
            bulletCircle(vec2i(), "bullet-purple")
            #makeRouter(vec2i(), diag = turn.mod(space * 2) == 0)
            
          if off mod (space*2) == 0:
            let cor = (off / (space * 2)).mod(mapSize * 2 + 1)
            var i = 0
            for corner in d4edge():
              makeRouter(corner * mapSize + vec2l(i * 90f.rad + 180f.rad, cor).vec2i, length = 3)
              i.inc
        
        #TODO bad pattern
        template sineBullets(offset: int) =
          for i in signsi():
            makeBullet(vec2i(i * ((turn - offset).mod(mapSize * 2 + 1) - mapSize), -mapSize), vec2i(0, 1))
            makeBullet(vec2i(i * ((turn - offset + mapSize).mod(mapSize * 2 + 1) - mapSize), -mapSize), vec2i(0, 1))
        
        template sideSorters =
          let spacing = 8
          if turn mod spacing == 0:
            for i in signsi():
              makeSorter(vec2i(mapSize * i, (mapSize - 1) * i), vec2i(-i, 0))

        if turn == 32:
          sideWeave()

        if turn in 0..38:
          sideConveyors()

        if turn in 35..44:
          sideBullets()

        if turn in 41..60:
          timeStrikes()
        
        if turn in 60..85:
          topDownConveyors()
        
        #fade in
        if turn == 95 or turn == 159:
          midBullets()
        
        if turn in 100..120:
          sideSorters()
          rightConveyors()
        
        #132, it is safe to begin next pattern
        if turn == 132:
          quadDuos()
        
        if turn in 160..180:
          crossRouters()
        
        if turn in 185..210:
          sideSorters()
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