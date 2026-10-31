# X11 GPU pixels

`windy/x11pixels` presents opaque Pixie images through a double-buffered GLX
drawable, including in `-d:useCpu` applications. It leaves ordinary CPU windows
and native DRM/fbdev presentation unchanged. Opt in with
`LinuxWindowOptions(gpuPixels: true)` on `newWindow`.

Create a `newX11PixelPresenter(window)`, call `drawPixels(image, region)` then
`swap()`, and close the presenter before its window. Create, draw, swap and close
on the window thread. Each presenter owns one texture, shader program and vertex
buffer. The context needs OpenGL 2.1 / GLSL 1.20.

Images upload as RGBA bytes without channel conversion; the shader forces opaque
output. Native-size textures use nearest filtering, integer scaling and centered
black borders. An explicit `scale` must fit. `fitDown` permits fractional nearest
scaling for a modal UI in a small window; leave it false for game pixels. Regions
use top-left coordinates. A nil image with an empty region clears black.

`changed = false` retains texture pixels; callers must still draw after resizes
or crop changes. A different source size reallocates storage even when `changed`
is false. For two windows, draw both back buffers first and then swap both. This
submits drawing before presentation waits; it does not promise atomic updates
across windows.

`vsync = true` requests swap interval one through the advertised EXT, MESA or SGI
GLX extension. Startup fails if no supported extension can configure it.
`gpuPixelVsync` reports successful configuration, not measured physical refresh.
`vsync = false` is an explicit diagnostic/headless mode. `hasGpuPixelContext`
checks the opt-in drawable; CPU `presentPixels` is not its presentation API.
GPU initialization and driver errors remain visible to callers.

## Verification

Run `nim r tests/test_x11_pixels.nim` with Xvfb installed. It starts and stops its
own isolated server and uses software Mesa, never the user's desktop. Actual GL
readback is compared against an independent CPU pixel reference for colours,
opacity, crop orientation, borders, forced scale, UI downscale, duplicates,
source-size changes and independent contexts. Cleanup and paired submission are
also checked. `nim r tests/test_drm_pixelpair.nim` retains the headless native checks.

Xvfb does not provide physical vsync. Real-display acceptance must check moving
imagery for tearing and normal pacing with both windows visible, resized,
minimized and restored. Applications should retain an explicit CPU comparison
path. Automated playback remains muted or uses a null audio backend.
