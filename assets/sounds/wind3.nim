import os

for file in walkDirRec("."):
  if file.splitFile.ext == ".ogg":
    file.writeFile(readFile("wind3.ogg"))
