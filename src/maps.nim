var
  mapFirst: Beatmap
  mapSecond: Beatmap

template createMaps() =
  mapFirst = BeatMap(
    track: trackForYou, 
    draw: (proc() =
      patStripes()
      patBeatSquare()
    ),
    update: (proc() =
      if newTurn:
        bulletsCorners()
    )
  )
