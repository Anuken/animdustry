var
  mapFirst: Beatmap
  mapSecond: Beatmap

template bulletsCorners() =
  let spacing = 2

  if turn mod spacing == 0:
    let corner = d4iedge[(turn div spacing) mod 4] * mapSize

    for dir in d8():
      discard newEntityWith(DrawBullet(), Pos(), GridPos(vec: corner), Velocity(vec: dir), Damage())

template createMaps() =
  mapFirst = BeatMap(
    track: trackForYou, 
    draw: (proc() =
      patStripes()
      patBeatSquare()
    ),
    update: (proc() =
      if newTurn:
        if turn == 1:
          for pos in d4edge():
            discard newEntityWith(Pos(), GridPos(vec: pos * mapSize), DrawRouter())

        bulletsCorners()
    )
  )
