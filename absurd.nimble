version       = "0.0.1"
author        = "Anuken"
description   = "Animedustry"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["main"]
binDir        = "jni"

requires "nim >= 1.6.2"
requires "https://github.com/Anuken/fau#" & staticExec("git -C fau rev-parse HEAD")
requires "zippy >= 0.7.3"
requires "flatty >= 0.2.3"
requires "jsony >= 1.1.3"

import strformat, os, json, sequtils

template shell(args: string) =
  try: exec(args)
  except OSError: quit(1)

const
  app = "main"
  
  builds = [
    (name: "linux64", os: "linux", cpu: "amd64", args: ""),
    (name: "win64", os: "windows", cpu: "amd64", args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++"),
    (name: "mac64", os: "macosx", cpu: "amd64", args: "")
  ]

task pack, "Pack textures":
  shell &"faupack -p:{getCurrentDir()}/assets-raw/sprites -o:{getCurrentDir()}/assets/atlas --outlineFolder=outlined"

task debug, "Debug build":
  shell &"nim r -d:debug src/{app}"

task debugBin, "Create debug build file":
  shell &"nim -d:debug -o:build/{app} --debugger:native src/{app}"

task release, "Release build":
  shell &"nim r -d:release -d:danger -o:build/{app} src/{app}"

task web, "Deploy web build":
  mkDir "build/web"
  shell &"nim c -f -d:emscripten -d:danger src/{app}.nim"
  writeFile("build/web/index.html", readFile("build/web/index.html").replace("$title$", capitalizeAscii(app)))

task deploy, "Build for all platforms":
  packTask()

  for name, os, cpu, args in builds.items:
    if commandLineParams()[^1] != "deploy" and not name.startsWith(commandLineParams()[^1]):
      continue
    
    if (os == "macosx") != defined(macosx):
      continue

    let
      exeName = &"{app}-{name}"
      dir = "build"
      exeExt = if os == "windows": ".exe" else: ""
      bin = dir / exeName & exeExt

    mkDir dir
    shell &"nim --cpu:{cpu} --os:{os} --app:gui -f {args} -d:danger -o:{bin} c src/{app}"
    if not defined(macosx):
      shell &"strip -s {bin}"

  #webTask()
  #cd "build"
  #shell &"zip -9r {app}-web.zip web/*"