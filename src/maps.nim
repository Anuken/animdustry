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
  #4: fade-in ends
  #38: beat starts
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
        if turn == 1:
          for pos in d4edge():
            discard newEntityWith(Pos(), GridPos(vec: pos * mapSize), DrawRouter())

        bulletsCorners()
    )
  )
