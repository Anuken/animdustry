var
  mapFirst: Beatmap
  mapSecond: Beatmap

template bulletsCorners() =
  let spacing = 2

  if turn mod spacing == 0:
    let corner = d4iedge[(turn div spacing) mod 4] * mapSize

    for dir in d8():
      discard newEntityWith(DrawBullet(), Pos(), GridPos(vec: corner), Velocity(vec: dir), Damage())

template bullet(pos: Vec2i, dir: Vec2i) =
  discard newEntityWith(DrawBullet(), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage())

template conveyor(pos: Vec2i, dir: Vec2i, length = 2) =
  discard newEntityWith(DrawConveyor(), Pos(), GridPos(vec: pos), Velocity(vec: dir), Damage(), Snek(len: length))

template bulletCircle(pos: Vec2i) =
  for dir in d8():
    bullet(pos, dir)

proc modSize(num: int): int =
  num.mod(mapSize * 2 + 1) - mapSize

template createMaps() =
  #4: fade-in ends
  #35: beat starts
  #70: "you"
  #85/86 "you" 2
  #104: new sound
  #228: resume

  mapFirst = BeatMap(
    track: trackForYou, 
    draw: (proc() =
      
      patStripes()
      patBeatSquare()
      #patFft()
    ),
    update: (proc() =
      if newTurn:
        #make routers at first turn.
        #if turn == 1:
        #  for pos in d4edge():
        #    discard newEntityWith(Pos(), GridPos(vec: pos * mapSize), DrawRouter())

        #bulletsCorners()

        let space = 4

        #TODO after 35, new pattern
        if turn in 0..35:
          if turn mod space == 0:
            let dir = (((turn div space).mod 2) == 0).signi
            for i in signsi():
              conveyor(vec2i(-mapSize * dir, ((turn div space).mod(mapSize + 1)) * i), vec2i(dir, 0))
        else:
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
          
          #runDelay(1, proc() =
          #  #echo "router"
          #)

        if turn == 35:
          for i in signsi():
            conveyor(vec2i(mapSize, mapSize) * i, vec2i(0, -i), 5)
        
        #TODO routers?
        if turn > 35:
          discard

        #if turn in 4..20:
        #  bulletsCorners()
    )
  )
