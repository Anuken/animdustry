register(defaultCompOpts):
  type 
    Input = object
      hitTurn: int
      nextBeat: int
      lastInputTime: float32
      lastSwitchTime: float32
      justMoved: bool
      couldMove: bool
      lastMove: Vec2i
      shielded: bool
      fails: int
      moves: int
      shieldCharge: int
  
    GridPos = object
      vec: Vec2i
    
    UnitDraw = object
      unit: Unit
      side: bool
      beatScl: float32
      shieldTime: float32
      scl: float32
      switchTime: float32
      hitTime: float32
      walkTime: float32
      failTime: float32
    
    Velocity = object
      vec: Vec2i
      space: int
    
    Scaled = object
      scl: float32
      time: float32
    
    DrawBullet = object
      rot: float32
      sprite: string
    
    DrawSpin = object
      sprite: string

    DrawSquish = object
      sprite: string

    DrawBounce = object
      sprite: string
      rotation: float32

    DrawLaser = object
      dir: Vec2i
    
    DrawDamageField = object

    Bounce = object
      count: int
    
    LeaveBullet = object
      life: int

    Turret = object
      dir: Vec2i
      reload: int
      reloadCounter: int

    Lifetime = object
      turns: int
    
    Deleting = object
      time: float32
    
    #can be hit by player attacks
    Destructible = object

    #block attacks for the player
    Wall = object
      health: int

    Snek = object
      turns: int
      produced: bool
      gen: int
      fade: float32
      len: int
    
    SpawnConveyors = object
      len: int
      diagonal: bool
      #TODO merge with diagonal
      alldir: bool
      dir: Vec2i
    
    SpawnEvery = object
      space: int
      offset: int
      spawn: SpawnConveyors
    
    Damage = object

    RunDelay = object
      delay: int
      callback: proc()
  
#snap position to grid position
GridPos.onAdd:
  let pos = entity.fetch(Pos)
  if pos.valid:
    pos.vec = curComponent.vec.vec2