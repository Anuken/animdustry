version       = "0.0.1"
author        = "Anuken"
description   = "3D test"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["main"]
binDir        = "build"

requires "nim >= 1.4.8"
requires "https://github.com/Anuken/fau#" & staticExec("git -C fau rev-parse HEAD")

import strformat, os

template shell(args: string) =
  try: exec(args)
  except OSError: quit(1)

const
  app = "main"

  builds = [
    #slightly broken and mostly unnecessary
    #(name: "win32", os: "windows", cpu: "i386", args: "--gcc.exe:i686-w64-mingw32-gcc --gcc.linkerexe:i686-w64-mingw32-g++"),
    (name: "win64", os: "windows", cpu: "amd64", args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++"),
  ]

task pack, "Pack textures":
  shell &"faupack -p:{getCurrentDir()}/assets-raw/sprites -o:{getCurrentDir()}/assets/atlas"

task debug, "Debug build":
  shell &"nim r -d:debug src/{app}"

task release, "Release build":
  shell &"nim r -d:release -d:danger -d:noFont -o:build/{app} src/{app}"

#TODO -d:danger etc
task lib, "Create library":
  shell &"nim c --app:lib --noMain:on -d:javaBackend -o:build/libabsurd.so src/{app}"

task web, "Deploy web build":
  mkDir "build/web"
  shell &"nim c -f -d:emscripten -d:danger src/{app}.nim"
  writeFile("build/web/index.html", readFile("build/web/index.html").replace("$title$", capitalizeAscii(app)))

task deploy, "Build for all platforms":
  webTask()

  for name, os, cpu, args in builds.items:
    let
      exeName = &"{app}-{name}"
      dir = "build"
      exeExt = if os == "windows": ".exe" else: ""
      bin = dir / exeName & exeExt
      #win32 crashes when the release/danger/optSize flag is specified
      dangerous = if name == "win32": "" else: "-d:danger"

    mkDir dir
    shell &"nim --cpu:{cpu} --os:{os} --app:gui -f {args} {dangerous} -o:{bin} c src/{app}"
    shell &"strip -s {bin}"
    shell &"upx-ucl --best {bin}"

  cd "build"
  shell &"zip -9r {app}-web.zip web/*"
