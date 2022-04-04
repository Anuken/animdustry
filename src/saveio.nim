import jsony, zippy, os, vars, types, strformat, core, fau/assets

#TODO: use system provided directory
let 
  dataDir = getSaveDir("absurd")
  dataFile = dataDir / "data.bin"

echo "DATA DIR: ", dataDir

proc parseHook*(s: string, i: var int, u: var Unit) =
  var str: string
  parseHook(s, i, str)
  if str == "nil":
    u = nil
    return
  for other in allUnits:
    if other.name == str:
      u = other
      return
  
  u = unitMono

proc dumpHook*(s: var string, u: Unit) =
  s.add '"'
  s.add if u == nil: "nil" else: u.name
  s.add '"'

proc saveGame* =
  ## Saves game data to deflated JSON.
  let data = save.toJson()
  let comp = compress(data, dataFormat = dfDeflate)

  dataDir.createDir()

  try:
    dataFile.writeFile(comp)
  except IOError:
    echo &"Error: Failed to write save data: {getCurrentExceptionMsg()}"

proc loadGame* =
  ## Loads game data from the save file. Does nothing if there is no data.
  if fileExists(dataFile):
    try:
      save = uncompress(dataFile.readFile, dataFormat = dfDeflate).fromJson(SaveState)
      echo "Loaded game state."
    except JsonError: echo &"Invalid save state JSON: {getCurrentExceptionMsg()}"
    except ZippyError: echo &"Corrupt save state data: {getCurrentExceptionMsg()}"
    except IOError: echo &"Error: Save data cannot be read: {getCurrentExceptionMsg()}"
    except OSError: echo &"OS error: {getCurrentExceptionMsg()}"