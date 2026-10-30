type
  PixelRegion* = object
    x*, y*, width*, height*: int
  GpuFlipPair* = object
    crtcs*: array[2, uint32]
    completed*: set[range[0..1]]
    timestamps*: array[2, uint64]

proc validateRegions*(width, height: int, regions: array[2, PixelRegion]) =
  ## Validate source crops; an empty region leaves its output black.
  for region in regions:
    if region == PixelRegion(): continue
    if width <= 0 or height <= 0 or region.x < 0 or region.y < 0 or
        region.width <= 0 or region.height <= 0 or region.x > width or
        region.y > height or region.width > width - region.x or
        region.height > height - region.y:
      raise newException(ValueError, "Invalid pixel source region")

proc pixelViewport*(region: PixelRegion, width, height: int): PixelRegion =
  ## Center whole-number scaling, clipping at native size when necessary.
  if min(region.width, region.height) <= 0 or min(width, height) <= 0:
    raise newException(ValueError, "Invalid pixel viewport dimensions")
  let scale = max(1, min(width div region.width, height div region.height))
  result.width = region.width * scale
  result.height = region.height * scale
  result.x = (width - result.width) div 2
  result.y = (height - result.height) div 2

proc pixelVertices*(width, height: int, regions: array[2, PixelRegion]): array[48, cfloat] =
  ## Address top-left source crops with OpenGL's bottom-left vertex convention.
  validateRegions(width, height, regions)
  if width <= 0 or height <= 0: return
  for index, region in regions:
    let
      left = cfloat(region.x) / cfloat(width)
      right = cfloat(region.x + region.width) / cfloat(width)
      top = cfloat(region.y) / cfloat(height)
      bottom = cfloat(region.y + region.height) / cfloat(height)
      vertices = [-1.cfloat, -1, left, bottom, 1, -1, right, bottom,
        -1, 1, left, top, -1, 1, left, top, 1, -1, right, bottom, 1, 1, right, top]
    for offset, value in vertices: result[index * vertices.len + offset] = value

proc complete*(pair: var GpuFlipPair, crtc: uint32, timestamp: uint64) =
  ## Record one event per controller before either old scanout can be retired.
  for index in 0..1:
    if pair.crtcs[index] == crtc:
      if index in pair.completed: raise newException(ValueError, "Duplicate flip completion")
      pair.completed.incl index
      pair.timestamps[index] = timestamp
      return
  raise newException(ValueError, "Completion from an unexpected CRTC")

proc ready*(pair: GpuFlipPair): bool =
  ## Return whether both controllers have completed the generation.
  pair.completed == {0, 1}
