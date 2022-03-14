
template bulletsCorners() =
  let spacing = 2

  if turn mod spacing == 0:
    let corner = d4iedge[(turn div spacing) mod 4] * 5

    for dir in d8():
      discard newEntityWith(DrawBullet(), Pos(), GridPos(vec: corner), Velocity(vec: dir), Damage())