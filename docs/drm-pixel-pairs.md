# GPU pixel pairs

`windy/drmpixels` adds GPU-scaled pixel presentation for two native DRM windows.
The caller supplies their order and source crops; device identities and game
layouts remain application concerns. Existing X11/fbdev/CPU rendering is retained.

Enable Windy's DRM backend in the project's Nim configuration. Create two equal,
unrotated native windows on one DRM device with independent controllers, then
claim their pair before presenting CPU pixels to either window:

```nim
import
  pixie, windy,
  windy/drmpixels

proc showPanels(first, second: Window, frame: Image) =
  ## Present two stacked panels without splitting their pixel storage.
  let
    pair = newDrmPixelPair(first, second)
    panelHeight = frame.height div 2
  defer: pair.close()
  pair.presentPixels(frame, [
    PixelRegion(width: frame.width, height: panelHeight),
    PixelRegion(y: panelHeight, width: frame.width, height: panelHeight)])
```

Keep the pair alive across frames. Source coordinates use the top-left origin;
a default/zero region leaves an output black. Scaling uses the largest positive
integer that fits, centered with black borders. Below native size it stays at1×
and clips to its output. Odd borders match CPU top/left centering.

The packed Pixie RGBA image is read only during the call. Crops share one texture
upload and one linear combined GBM framebuffer. There is no CPU enlargement,
screen splitting or readback in normal presentation. EGL has no depth/stencil
or MSAA. GBM/EGL/GLES libraries load only when creating a pair; software renderers
are rejected. Unsupported paired scanout does not choose another backend.

Both primary-plane framebuffer IDs change in one atomic transaction. Rendering
finishes before submission; old storage remains locked until both CRTC events
arrive. This coordinates generations, not physical panel refresh phases.
Presentation is synchronous and vblank paced; fencing/overlap is separate work.

Use the creating thread. The pair activates its EGL context for rendering and
cleanup. Keep windows alive for input and close the pair before either window.
Claiming releases their unused CPU scanout buffers; reopen windows to return to
CPU presentation. Closed pairs reject presentation and tolerate repeated close.
Initialization and cleanup errors propagate.

`tests/test_drm_pixelpair.nim` covers geometry, crops, event order and ownership.
`tests/manual_drm_pixelpair.nim CARD TOP BOTTOM` reads every GPU pixel and tests
real flips, odd borders, resizing, clipping, black outputs and swaps. Physical
tests need exclusive display ownership and a bounded service-restoring runner.
Initial measurements are in [the proof guide](drm-gpu-proof.md).
