version       = "0.0.1"
author        = "Anuken"
description   = "3D test"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["main"]
binDir        = "jni"

requires "nim >= 1.6.2"
requires "https://github.com/Anuken/fau#" & staticExec("git -C fau rev-parse HEAD")

import strformat, os, json, sequtils

template shell(args: string) =
  try: exec(args)
  except OSError: quit(1)

const
  app = "main"

  jnis = [
    #TODO linux would be nice.
    (name: "win64", os: "windows", cpu: "amd64", args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++"),
  ]

  wraps = "--passL:-Wl,-wrap,memcpy,-wrap,pow,-wrap,powf,-wrap,log,-wrap,logf,-wrap,exp,-wrap,expf,-wrap,clock_gettime,-wrap,stat,-wrap,fstat,-wrap,lstat"

task pack, "Pack textures":
  shell &"faupack -p:{getCurrentDir()}/assets-raw/sprites -o:{getCurrentDir()}/assets/atlas"

task debug, "Debug jni":
  shell &"nim r -d:debug src/{app}"

task release, "Release jni":
  shell &"nim r -d:release -d:danger -d:noFont -o:jni/{app} src/{app}"

#TODO -d:danger etc
task lib, "Create library":
  #signal handler needs to be disabled, https://github.com/yglukhov/jnim/issues/23#issuecomment-274284251
  shell &"nim c -f --app:lib --noMain:on -d:noSignalHandler -d:javaBackend -d:localAssets -o:jni/libabsurd.so src/{app}"

task web, "Deploy web jni":
  mkDir "jni/web"
  shell &"nim c -f -d:emscripten -d:danger src/{app}.nim"
  writeFile("jni/web/index.html", readFile("jni/web/index.html").replace("$title$", capitalizeAscii(app)))

task deploy, "Build for all platforms":
  webTask()

  for name, os, cpu, args in jnis.items:
    let
      exeName = &"{app}-{name}"
      dir = "jni"
      exeExt = if os == "windows": ".exe" else: ""
      bin = dir / exeName & exeExt
      #win32 crashes when the release/danger/optSize flag is specified
      dangerous = if name == "win32": "" else: "-d:danger"

    mkDir dir
    shell &"nim --cpu:{cpu} --os:{os} --app:gui -f {args} {dangerous} -o:{bin} c src/{app}"
    shell &"strip -s {bin}"
    shell &"upx-ucl --best {bin}"

  cd "jni"
  shell &"zip -9r {app}-web.zip web/*"

task android, "Android Build Nim":
  let cmakeText = "android/Android_template".readFile()
  let appText = "android/Application_template".readFile()

  #armeabi armeabi-v7a x86 x86_64 arm64-v8a

  for arch in ["32", "64"]:
    rmDir "android/build/jni"
    mkDir "android/build/jni"

    #specify architectures used, copy over file 1
    writeFile("android/build/jni/Application.mk", appText.replace("${ABIS}", if arch == "32": "x86 armeabi-v7a" else: "x86_64 arm64-v8a"))

    let cpu = if arch == "32": "" else: "64"

    #TODO -d:danger
    shell &"nim c -f --compileOnly --cpu:arm{cpu} --os:android -c --noMain:on -d:javaBackend -d:localAssets --nimcache:android/build/jni/{arch} src/{app}.nim"

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