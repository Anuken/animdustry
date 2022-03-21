import zippy, pixie, tables, flatty/binny

## Implements the SUS image format. I'm sure this extension is taken by something less interesting, but I don't care.
## This is essentially a 256-color indexed format with run-length encoding and deflate compression. Very simple, but generally smaller and easier to decode than PNG.

proc writeSus*(image: Image): string =
  var buf = ""
  var palette = initTable[ColorRGBX, int]()
  var palSeq: seq[ColorRGBX]

  #color data index table, prevents table lookups
  var data = newSeq[uint8](image.data.len)

  #all empty alpha values are ignored
  const emptyCol = rgbx(0, 0, 0, 0)

  #generate palette based on colors (slow?)
  for index, col in image.data:
    var resultCol = col
    if resultCol.a == 0:
      resultCol = emptyCol
    
    if not palette.hasKey(resultCol):
      if palette.len >= 255:
        raise Exception.newException("SUS image can only contain 256 colors at most")
      
      data[index] = palette.len.uint8
      palette[resultCol] = palette.len
      palSeq.add resultCol
    else:
      data[index] = palette[resultCol].uint8

  #write size
  buf.addInt32(image.width.int32)
  buf.addInt32(image.height.int32)

  #write palette size + values
  buf.addUint8(palette.len.uint8)
  for key in palSeq:
    buf.addUint32(cast[uint32](key))

  #write consecutive colors.
  var i = 0
  let ilen = data.len
  while i < ilen:
    let curr = data[i]
    var consecutive = 0
    while data[i] == curr and consecutive < 255 and i < ilen:
      consecutive.inc
      i.inc
    
    buf.addUint8(curr)
    buf.addUint8(consecutive.uint8)
  
  return compress(buf, dataFormat = dfDeflate, level = BestCompression)

#TODO remove
proc readSus*(data: string): Image =
  var buf = uncompress(data, dataFormat = dfDeflate)
  var pos = 0

  let
    w = buf.readInt32(pos)
    h = buf.readInt32(pos + 4)
  pos += 8

  result = newImage(w, h)

  let palSize = buf.readUint8(pos)
  pos += 1
  var palette = newSeq[ColorRGBX](palSize)
  
  for i in 0..<palSize.int:
    palette[i] = cast[ColorRGBX](buf.readUint32(pos + i * 4))
  
  pos += palSize.int * 4

  let pixels = w * h
  var i = 0
  while i < pixels:
    let col = palette[buf.readUint8(pos)]
    pos += 1
    let amount = buf.readUint8(pos).int
    for oc in 0..<amount:
      result.data[i] = col
      i += 1
    pos += 1

proc readSusTexture*(data: string): Texture =
  var buf = uncompress(data, dataFormat = dfDeflate)
  var pos = 0

  let
    w = buf.readInt32(pos)
    h = buf.readInt32(pos + 4)
  pos += 8

  var data = newSeq[uint32](w * h)

  let palSize = buf.readUint8(pos)
  pos += 1
  var palette = newSeq[uint32](palSize)
  
  for i in 0..<palSize.int:
    palette[i] = buf.readUint32(pos + i * 4)
  
  pos += palSize.int * 4

  let pixels = w * h
  var i = 0
  while i < pixels:
    let col = palette[buf.readUint8(pos)]
    pos += 1
    let amount = buf.readUint8(pos).int
    for oc in 0..<amount:
      data[i] = col
      i += 1
    pos += 1
  
  return loadTexturePtr(vec2i(w, h), addr data[0])


when isMainModule:
  let img = readImage("/home/anuke/testimage.png")
  writeFile("/home/anuke/output.sus", writeSus(img))
  let read = readSus(readFile("/home/anuke/output.sus"))
  writeFile(read, "/home/anuke/roundTrip.png")
