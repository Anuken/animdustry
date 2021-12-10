import core, fau/g3/[mesh3, fmath3, meshbuild], fau/g2/[bloom, imui], math

var
  mesh: Mesh3
  cam: Cam3
  shader: Shader
  bl: Bloom
  pos: Vec2

type Character* = ref object
  name*: string

initFau((proc() =
  cam.pos = vec3(0, 5, 0)
  cam.lookAt(vec3(0, 0, 0))
  cam.update(fau.size)

  mesh.render(shader, meshParams(depth = true, buffer = bl.buffer)):
    proj = cam.combined * rot3(quatAxis(vec3X, fau.time * 2f) * quatAxis(vec3Y, fau.time * 2f))
    color = hsv((fau.time / 30f).mod 1f, 1f, 1f) + rgb(0.3f)

  bl.blit()

  pos += vec2(axis(keyA, keyD), axis(keyS, keyW)).nor * 10f

  screenMat()
  fillPoly(fau.size/2f + pos, 5, 50f, rotation = fau.time * 2f, color = colorGreen)

  when not defined(noAudio):
    if keyT.tapped: soundBreak.play()

  if keyEscape.tapped:
    quitApp()

), (proc() =
  when not defined(noAudio):
    musicGood.play(loop = true)

  mesh = makeCube()
  cam = newCam3()
  bl = newBloom(depth = true)

  shader = newShader("""
  attribute vec4 a_pos;
  attribute vec3 a_normal;
  attribute vec4 a_color;

  uniform mat4 u_proj;
  uniform vec4 u_color;

  varying vec4 v_col;

  void main(){
    vec3 nor = vec3(clamp((dot(a_normal, normalize(vec3(0.8, 1.0, 0.3))) + 1.0) / 2.0, 0.3, 1.0));
    v_col = a_color * u_color * vec4(nor, 1.0);
    gl_Position = u_proj * a_pos;
  }

  """,
  """
  varying vec4 v_col;

  void main(){
    gl_FragColor = v_col;
  }
  """
  )
), windowTitle = "3d", depth = true)
