import sugar, vars, core, types, math

var
  map1*, map2*, map3*, map4*, map5*: Beatmap

template delayBullet*(pos: Vec2i, dir: Vec2i, tex = "") =
  let 
    p = pos
    d = dir
  capture p, d:
    runDelay:
      makeBullet(p, d, tex)

template delayBulletWarn*(pos: Vec2i, dir: Vec2i, tex = "") =
  delayBullet(pos, dir, tex)
  effectWarnBullet(pos.vec2, rotation = dir.vec2.angle, life = beatSpacing())

template bulletCircle*(pos: Vec2i, tex = "") =
  for dir in d8():
    makeBullet(pos, dir, tex)

template laser*(pos, dir: Vec2i) =
  effectLancerAppear(pos.vec2 - dir.vec2/1.4f, life = beatSpacing() * 3f, rotation = dir.vec2.angle)
  
  let p = pos
  capture p:
    runDelayi 1:
      effectLaserShoot(p.vec2)
  
  for len in 0..(mapSize*2):
    let dest = pos + dir * len
    effectLaserWarn(dest.vec2, rotation = dir.vec2.angle, life = beatSpacing() * 2)
    capture dest:
      runDelayi 1:
        makeLaser(dest, dir)

proc modSize*(num: int): int =
  num.mod(mapSize * 2 + 1) - mapSize

template createMaps* =
  map1 = BeatMap(
    songName: "Aritus - For You",
    music: "forYou",
    bpm: 126f,
    beatOffset: -80f / 1000f,
    maxHits: 20,
    copperAmount: 4,
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

  map2 = Beatmap(
    songName: "PYC - Stoplight",
    music: "stoplight",
    bpm: 85f,
    beatOffset: 0f / 1000f,
    maxHits: 12,
    copperAmount: 5,
    fadeColor: %"985eb9",
    drawPixel: (proc() =
      patBackground(%"2b174d")
      patFadeShapes(%"4b2362")

      patStars(%"b3739a", %"e8c8b2")

      patClouds(%"653075")
      patBeatAlt(%"bf96eb")
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      if state.newTurn:
        let turn = state.turn

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
                  effectStrikeWave(pos.vec2, rotation = i.float32, life = beatSpacing())
                  if i == 3:
                    bulletCircle(pos, "bullet-purple")
        
        template topDownConveyors =
          let space = 8
          if turn mod space == 0:
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

  map3 = Beatmap(
    songName: "Keptor's Room - Bright 79", # (from Topaze Club)?
    music: "bright79",
    bpm: 127f,
    beatOffset: -80f / 1000f,
    maxHits: 15,
    copperAmount: 7,
    fadeColor: %"b291f2",
    drawPixel: (proc() =
      patGradient(
        %"b23b66",
        %"9961c6",
        %"463c8f",
        %"77a5c9"
      )

      patBounceSquares((%"463c8f").withA(0.45f))

      patTris(%"a886e9", %"d087f5", 90, seed = 4)

      patVertGradient((%"a886e9").withA(0.5f), (%"a886e9").withA(0f))
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"ff2eca")
    ),
    update: (proc() =
      if state.newTurn:
        let turn = state.turn

        template lasers =
          let space = 2
          const order = [0, 2, 4, 1, 3, 5, 0, 6, 1, 3]
          if turn mod space == 0:
            for i in signsi():
              let x = order[(turn div space) mod order.len] * i
              laser(vec2i(x, -mapSize), vec2i(0, 1))
        
        template sideConveyors =
          let space = 1
          let ss = 1
          if turn mod space == 0:
            let 
              vec = vec2i(mapSize, ((turn div space) - 1).modSize)
              rot = ((turn div space) div ss) mod 4
            
            let dest = vec.vec2.rotate(rot.float32 * 90f.rad).vec2i
            makeConveyor(dest, d4i[(rot + 2) mod 4], 5)
        
        template sideRouters(offset: int) =
          let
            t = turn - offset
            space = 2
          if t mod space == 0:
            let d = (t div space).modSize
            for i in signsi():
              makeRouter(vec2i(i * mapSize, d), diag = (t.div(space) mod 2) == 0, length = 3)

        template trackLasers =
          let space = 2
          if turn mod space == 0:
            let si = (turn.div(space) mod 2 == 0).signi
            laser(vec2i(mapSize * si, state.playerPos.y), vec2i(-si, 0))

        template multiLasers =
          for x in [0, 2, 4, 6]:
            for i in signsi():
              laser(vec2i(x * i, -mapSize), vec2i(0, 1))
        
        template swipeBullets(offset: int) =
          let
            t = turn - offset
            space = 1
          if t mod space == 0:
            let 
              x = (modSize((t div space) * 2))
              pos = vec2i(-x, 0)
            
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos, t:
              runDelay:
                if (t div space).mod(2) == 0:
                  for dir in d4():
                    makeBullet(pos, dir, "bullet-tri")
                else:
                  for dir in d4edge():
                    makeBullet(pos, dir, "bullet-tri")
            
        template sideLasers =
          let space = 1
          const order = [1, 3, 2, 0, 6, 4, 1, 3, 5, 4, 0]
          if turn mod space == 0:
            let i = (turn.div(space).mod(2) == 0).signi
            let y = order[(turn div space) mod order.len] * i
            laser(vec2i(-mapSize, y), vec2i(1, 0))
        
        template topConveyors =
          let space = 1
          const order = [6, 4, 2, 0, 5, 3, 1]
          if turn mod space == 0:
            let x = order[(turn div space) mod order.len]
            for i in signsi():
              makeConveyor(vec2i(x * i, -mapSize * i), vec2i(0, i), 2)
        
        template conveyorWall(dir = 1) =
          for i in -mapSize..mapSize:
            makeConveyor(-d4i[dir] * mapSize + d4i[(dir + 1) mod 4] * i, d4i[dir], length = 1)
        
        template sideSorters =
          let space = 6
          if turn mod space == 0:
            let side = d4i[(turn div space) mod 4]
            makeSorter(side * mapSize, -side)

        if turn in 0..39:
          sideConveyors()
        
        if turn in 41..90:
          lasers()
        
        if turn == 97 or turn == 130:
          multiLasers()
        
        if turn in 90..140:
          sideRouters(90)
        
        if turn in 148..161:
          trackLasers()
        
        if turn in 161..186:
          swipeBullets(161)
        
        if turn in 186..210:
          sideLasers()
        
        if turn in 208..245:
          topConveyors()
        
        if turn == 254:
          conveyorWall(0)
        
        if turn == 260:
          conveyorWall(1)

        if turn == 266:
          conveyorWall(2)
        
        if turn in 265..300:
          sideSorters()
        
        if turn in 297..338:
          lasers()
        
        if turn == 323:
          conveyorWall(3)

    )
  )

  map4 = Beatmap(
    songName: "Aritus - Pina Colada II",
    music: "pinacolada",
    bpm: 125f,
    beatOffset: -240f / 1000f,
    maxHits: 12,
    copperAmount: 8,
    fadeColor: %"b4b2ff",
    drawPixel: (proc() =
      patBackground(%"0d091d")

      patStars((%"46cdd2").withA(0.4f), (%"50e2b5").withA(1f), 70, 2)

      patSpinShape(%"1e1b36", %"393b5c")
      patSpace(%"1e1b36")
    ),
    draw: (proc() =
      patTilesSquare(%"b4b2ff", %"50e2b5")
    ),
    update: (proc() =
      if state.newTurn:
        let turn = state.turn

        template arcs =
          let space = 4
          if turn mod space == 0:
            let side = ((turn div space) mod 2) == 0
            makeArc(vec2i(mapSize, (turn div space).modSize), vec2i(-1, 1 * side.signi), bounces = 3, life = 5)
        
        template diagConveyors(offset: int) =
          let 
            space = 4
            t = turn - offset
          if t mod space == 0:
            let x = mapSize - ((t div space) * 2).mod(mapSize * 2)
            for i in signsi():
              if i == 1 or x != mapSize:
                if i == 1:
                  makeConveyor(vec2i(x, mapSize), vec2i(-1, -1), 3)
                else:
                  makeConveyor(vec2i(mapSize, x), vec2i(-1, -1), 3)

        template botSorters =
          let space = 6
          if turn mod space == 0:
            makeSorter(vec2i(0, -mapSize), vec2i(0, 1), 1, 2, 3)
        
        template topBounce = 
          for i in [2, 4]:
            for x in signsi():
              makeArc(vec2i(i * x, mapSize), vec2i(0, -1), bounces = 4)

        template sideBounce = 
          for i in [2, 4]:
            for y in signsi():
              makeArc(vec2i(mapSize, y * i), vec2i(-1, 0), bounces = 4)
        
        template sideDuos =
          for x in signsi():
            makeTurret(vec2i(mapSize * x, 0), vec2i(-x, 0), life = 25)

        template topDuos =
          for y in signsi():
            makeTurret(vec2i(0, mapSize * y), vec2i(0, -y), life = 25)
        
        template botConveyors =
          for x in -mapSize..mapSize:
            if x.mod(2) == 0:
              makeConveyor(vec2i(x, -mapSize), vec2i(0, 1), 1)
        
        template topWall =
          let space = 8
          if (turn - 1) mod space == 0:
            for x in -mapSize..mapSize:
              if x.mod(2) != 0:
                makeConveyor(vec2i(x, mapSize), vec2i(0, -1), 1)

        template sideLasers(offset: int) = 
          let 
            space = 4
            t = turn - offset
          if t mod space == 0:
            laser(vec2i(mapSize, (((t div space) - mapSize div 2) * 2)), vec2i(-1, 0))
        
        template followRouters =
          let space = 4
          if turn mod space == 0:
            let 
              pos = state.playerPos
              diagonal = ((turn div space).mod 2) == 0
            effectWarn(pos.vec2, life = beatSpacing() * 3)
            capture pos:
              runDelayi 2:
                makeRouter(pos.vec2i, 3, diag = diagonal)

        template waveConveyors =
          for x in -mapSize..mapSize:
            makeConveyor(vec2i(x, mapSize), vec2i(0, -1), 2)
        
        template targetArcs =
          let space = 6
          if turn mod space == 0:
            let pos = vec2i(state.playerPos.x, -mapSize)
            effectWarn(pos.vec2, life = beatSpacing() * 2)
            capture pos:
              runDelayi 1:
                makeArc(pos, vec2i(0, 1), bounces = 0)

        template diagonalRouters(offset: int) =
          let 
            t = turn - offset
            space = 2
          
          if t mod space == 0:
            let 
              pos = vec2i(t div space) - vec2i(mapSize)
              dia = (t div space) mod 2 == 0
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos, dia:
              runDelay:
                makeRouter(pos, diag = dia, length = 4)
           
        if turn in 2..52:
          arcs()
        
        if turn in 52..80:
          diagConveyors(52)
        
        if turn in 80..100:
          botSorters()
        
        if turn == 101:
          topBounce()
        
        if turn == 105:
          sideDuos()
        
        if turn == 113:
          sideBounce()
        
        if turn == 122:
          topDuos()

        if turn in 155..200:
          botConveyors()
        
        if turn in 162..200:
          topWall()
        
        if turn in 170..197:
          sideLasers(170)
        
        if turn in 204..235:
          followRouters()
        
        if turn == 234 or turn == 245:
          waveConveyors()
        
        if turn in 238..274:
          targetArcs()
        
        if turn in 270..294:
          diagonalRouters(270)
    )
  )

  map5 = Beatmap(
    songName: "ADRIANWAVE - Peach Beach",
    music: "peachBeach",
    bpm: 121f,
    beatOffset: 0f / 1000f,
    maxHits: 10,
    copperAmount: 8,
    fadeColor: %"fa874c",
    drawPixel: (proc() =
      #TODO better background, with beats
      patBackground(%"b25aab")

      patVertGradient(
        %"33256f",
        %"fa874c"
      )

      #patFft(vec2(0f, 1.5f), 62f.px, color = %"fea955")

      draw("beach".patch, vec2(0, -fau.cam.size.y / 2f), align = daBot)

      patCircles((%"d47ddd").mix(%"ffaa55", state.moveBeat * 0.8f), size = 1.5f..8f, amount = 120, seed = 10, moveSpeed = 0.1f)

      patLongClouds(%"5d59a6")

      patVertGradient(
        (%"33256f").withA(0.5f),
        (%"fa874c").withA(0.5f)
      )

      draw("sun".patch, vec2(0f, 1.5f))

      patSpinGradient(vec2(0f, 4f), (%"ffb65f").withA(0.7f), (%"fea956").withA(0f), 20f, 14, spacing = 1)

      #fillPoly(vec2(0f, 4f), 30, 3.3f, color = %"ff7157")
      #fillPoly(vec2(0f, 4f), 30, 3f, color = %"ffa95a")
      
      #patRain()
    ),
    draw: (proc() =
      patTilesSquare(%"cbb2ff", %"fa874c")
    ),
    update: (proc() =
      if state.newTurn or (state.turn == 0 and sysSnek.groups.len == 0):
        let turn = state.turn

        template botLeftConvey(offset = 0) = 
          let
            t = turn - offset
            space = 8
          if t mod space == 0:
            for i in 0..4:
              makeConveyor(vec2i(-mapSize + i, -mapSize), vec2i(0, 1), 3)
        
        template topRightConvey(offset = 4) = 
          let
            t = turn - offset
            space = 8
          if t mod space == 0:
            for i in 0..4:
              makeConveyor(vec2i(mapSize - i, mapSize), vec2i(0, -1), 3)
        
        template botLeftSideConvey(offset = 0) = 
          let
            t = turn - offset
            space = 8
          if t mod space == 0:
            for i in 0..4:
              makeConveyor(vec2i(-mapSize, -mapSize + i), vec2i(1, 0), 3)

        template topRightSideConvey(offset = 4) = 
          let
            t = turn - offset
            space = 8
          if t mod space == 0:
            for i in 0..4:
              makeConveyor(vec2i(mapSize, mapSize - i), vec2i(-1, 0), 3)
        
        template botTrackLaser =
          let space = 2
          if (turn - 1) mod space == 0:
            laser(vec2i(state.playerPos.x, -mapSize), vec2i(0, 1))

        template sideBursts =
          let space = 4
          if turn mod space == 0:
            let 
              d = (turn div space) mod 4
              pos = d8i[d] * 5
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos:
              runDelay:
                bulletCircle(pos, "bullet-pink")

        template trackConveyors =
          let space = 2
          if turn mod space == 0:
            let pos = vec2i(state.playerPos.x, -mapSize)
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos:
              runDelay:
                makeConveyor(pos, vec2i(0, 1), 3)

        template midOverflow(offset: int) =
          if (turn - offset) mod 8 == 0:
            effectWarn(vec2(), life = beatSpacing())
            runDelay:
              makeRouter(vec2i(), alldir = true, sprite = "overflow-gate", length = 3)

        template sideBullets(offset: int) =
          if turn == offset:
            var rot = 0
            for dir in d4():
              for i in -1..1:
                let pos = dir + vec2i(mapSize, i).rotate(rot)
                delayBulletWarn(pos, -dir, "bullet-pink")
              rot.inc
        
        template diagBullets(offset: int) =
          if (turn - offset) mod 8 == 0:
            for dir in d8():
              let pos = dir * mapSize
              effectWarn(pos.vec2, life = beatSpacing())
              capture pos:
                runDelay:
                  bulletCircle(pos, "bullet-pink")
        
        template trackConveyorTop =
          let space = 4
          if turn mod space == 0:
            let pos = vec2i(state.playerPos.x, mapSize)
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos:
              runDelay:
                makeConveyor(pos, vec2i(0, -1), 1)
        
        template diagOverflows(offset: int) =
          if (turn - offset) mod 8 == 0:
            var rot = 0
            let t = (turn - offset) div 8
            for dir in d4edge():
              let pos = dir * (mapSize - 1) + (vec2i(-1, 0).rotate(rot) * (t + 1))
              rot.inc
              effectWarn(pos.vec2, life = beatSpacing())
              capture pos:
                runDelay:
                  makeRouter(pos, alldir = true, sprite = "overflow-gate", length = 2)

        template diagArcs =
          var rot = 0
          for dir in d4():
            let 
              pos = dir * mapSize
              dir = vec2i(-1, 1).rotate(rot)
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos, dir:
              runDelay:
                makeArc(pos, dir, bounces = 3)
            rot.inc

        template timeStrikes =
          let space = 3

          if turn mod space == 0:
            let pos = state.playerPos
            for i in 0..3:
              capture i, pos:
                runDelayi(i):
                  effectStrikeWave(pos.vec2, rotation = i.float32, life = beatSpacing())
                  if i == 3:
                    bulletCircle(pos, "bullet-pink")

        template randomConveyors =
          const xs = [0, 1, 3, 5, 2, 4, 6, 0, 2, 4]
          let space = 2

          if turn mod space == 0:
            for i in signsi():
              let pos = vec2i(xs[(turn div space) mod xs.len] * i, -mapSize * ((turn div space).mod(2) == 0).signi)
              if pos.x == 0 and i != 1: continue
              makeConveyor(pos, vec2i(0, -pos.y.sign), 8)
        
        template bouncespam =
          let space = 4
          if turn mod space == 0:
            let y = ((turn div space) * 2).modSize
            for i in signsi():
              makeArc(vec2i(i * mapSize, y), vec2i(-1 * i, 1), bounces = 4, life = 2)
        
        template moreDiagBullets =
          if turn mod 4 == 0:
            for dir in d8():
              let pos = dir * mapSize
              effectWarn(pos.vec2, life = beatSpacing())
              capture pos:
                runDelay:
                  for dir in d4():
                    makeBullet(pos, dir, "bullet-pink")

        template diagSorters =
          for i in signsi():
            makeSorter(vec2i(-mapSize * i, -mapSize), vec2i(i, 1))
        
        template passageLasers =
          let space = 4
          if turn mod space == 0:
            for i in -mapSize..mapSize:
              if ((turn div space) mod 2) == i.emod(2):
                laser(vec2i(i, -mapSize), vec2i(0, 1))
        
        template botRouters(offset: int) =
          var t = (turn - offset - mapSize)
          if t > mapSize:
            t -= (mapSize * 2 + 1);

          if t <= mapSize:
            let pos = vec2i(0, t)
            effectWarn(pos.vec2, life = beatSpacing())
            capture pos:
              runDelay:
                makeRouter(pos, length = 1)

        if turn in 0..62:
          botLeftConvey()
          topRightConvey()
        
        if turn in 15..62:
          botTrackLaser()
        
        if turn == 34 or turn == 34 + mapSize*2 + 1:
          makeArc(vec2i(mapSize, 0), vec2i(-1, 0), bounces = 2)
        
        if turn in 64..95:
          sideBursts()
        
        if turn in 68..91:
          trackConveyors()
        
        if turn in 94..124:
          midOverflow(94)
          sideBullets(94)
        
        if turn in 98..124:
          trackConveyorTop()
        
        if turn in 97..124:
          diagBullets(97)
        
        #130 = again
        if turn in 127..159:
          diagOverflows(127)
          if turn == 127:
            diagArcs()
        
        #156: alternating top/bot left conveyors
        if turn in 156..186:
          botLeftSideConvey()
          topRightSideConvey()

        if turn in 168..188:
          timeStrikes()
        
        #breakdown
        if turn in 188..220:
          randomConveyors()
          
        if turn in 220..242:
          bounceSpam()

        if turn in 220..246:
          moreDiagBullets()
      
        if turn == 248:
          diagSorters()
        
        if turn == 252:
          for i in signsi():
            makeTurret(vec2i(mapSize * i, 0), vec2i(-i, 0), life = 20, reload = 3)
        
        if turn in 272..284:
          passageLasers()
        
        if turn in 280..310:
          randomConveyors()
        
        if turn in 300..340:
          botRouters(300)
    )
  )