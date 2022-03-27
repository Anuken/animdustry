version       = "0.0.1"
author        = "Anuken"
description   = "3D test"
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
  #signal handler needs to be disabled, https://github.com/yglukhov/jnim/issues/23#issuecomment-274284251
  libArgs = "--app:lib --noMain:on -d:noSignalHandler -d:javaBackend -d:localAssets"

  builds = [
   #(name: "linux64", os: "linux", cpu: "amd64", args: ""), #doesn't really work due to glibc
    (name: "win64", os: "windows", cpu: "amd64", args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++"),
  ]

task pack, "Pack textures":
  shell &"faupack -p:{getCurrentDir()}/assets-raw/sprites -o:{getCurrentDir()}/assets/atlas --outlineFolder=outlined"

task debug, "Debug build":
  shell &"nim r -d:debug src/{app}"

task release, "Release build":
  shell &"nim r -d:release -d:danger -o:build/{app} src/{app}"

task lib, "Create library for testing":
  shell &"nim c -f -d:danger {libArgs} -o:build/libabsurd.so src/{app}"

task web, "Deploy web build":
  mkDir "build/web"
  shell &"nim c -f -d:emscripten -d:danger src/{app}.nim"
  writeFile("build/web/index.html", readFile("build/web/index.html").replace("$title$", capitalizeAscii(app)))

task deploy, "Build for all platforms":
  #webTask()
  pack()

  for name, os, cpu, args in builds.items:
    let
      exeName = &"{app}-{name}"
      dir = "build"
      exeExt = if os == "windows": ".exe" else: ""
      bin = dir / exeName & exeExt

    mkDir dir
    shell &"nim --cpu:{cpu} --os:{os} --app:gui -f {args} -d:danger -o:{bin} c src/{app}"
    shell &"strip -s {bin}"
    #shell &"upx-ucl --best {bin}"

  #cd "build"
  #shell &"zip -9r {app}-web.zip web/*"

task android, "Build android version of lib":
  let cmakeText = "android/Android_template".readFile()
  let appText = "android/Application_template".readFile()

  for arch in ["32", "64"]:
    rmDir "android/build/jni"
    mkDir "android/build/jni"

    #specify architectures used, copy over file 1
    writeFile("android/build/jni/Application.mk", appText.replace("${ABIS}", if arch == "32": "x86 armeabi-v7a" else: "x86_64 arm64-v8a"))

    let cpu = if arch == "32": "" else: "64"

    shell &"nim c -d:danger --compileOnly --cpu:arm{cpu} --os:android -c --noMain:on -d:javaBackend -d:localAssets --nimcache:android/build/jni/{arch} src/{app}.nim"

    let includes = @[
      "/home/anuke/.choosenim/toolchains/nim-1.6.2/lib",
      "/home/anuke/Projects/soloud/include"
    ]
    var sources: seq[string]

    let compData = parseJson(readFile(&"android/build/jni/{arch}/{app}.json"))
    let compList = compData["compile"]
    for arr in compList.items:
      sources.add(arr[0].getStr)

    writeFile("android/build/jni/Android.mk", cmakeText
    .replace("${NIM_SOURCES}", sources.join("\\\n  "))
    .replace("${NIM_INCLUDES}", includes.mapIt(it.replace("#", "\\#")).join("\\\n  ")))

    cd "android/build/jni"
    shell "/home/anuke/Android/Ndk/ndk-build"
    cd "../../../"
  
  shell "cp -r android/build/libs/* build/lib"

task libs, "Create libraries for all platforms":
  rmDir "build/libs"
  mkDir "build"

  for name, os, cpu, args in builds.items:
    let
      prefix = if os == "windows": "" else: "lib"
      exeName = prefix & "absurd64"
      libExt = if os == "windows": ".dll" else: ".so"
      bin = "build/lib/" / exeName & libExt

    shell &"nim --cpu:{cpu} --os:{os} {libArgs} -f {args} -d:danger -o:{bin} c src/{app}"
    shell &"strip -s {bin}"
  
  androidTask()