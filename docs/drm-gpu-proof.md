# Standalone DRM/GBM/EGL proof

`tests/manual_drm_gpu.nim` is an experiment, not a new Windy rendering API.
The production X11, fbdev and CPU DRM backends are unchanged. Its private
bindings use the existing libdrm loader and dynamically load libgbm, libEGL and
libGLESv2. It requires a 64-bit little-endian Linux system with two equally sized
connected outputs, hardware Mesa rendering and exclusive display ownership.

Compile with `nim c tests/manual_drm_gpu.nim`. Its project-specific test
configuration enables release/danger unless `debug` is defined. For ARM64 use
the existing `WINDY_TEST_TARGET=arm64` and `MONO_RETRO_CC` configuration. No new
Nim dependency is needed.

```
manual_drm_gpu CARD TOP_CONNECTOR BOTTOM_CONNECTOR ds|earthbound xbgr|xrgb gpu|cpu|inspect [seconds]
```

`inspect` initializes EGL, renders and checks pixels, but never acquires DRM
master or changes scanout. Other modes temporarily own both displays. Stop the
display service before running them; use an outer timeout and restore the service
on exit. Duration defaults to eight seconds and accepts only 1..8. Initialization
and cleanup are additional to the measured loop, so allow a small watchdog grace.
Do not run beside games, compiler jobs or other performance tests.

## Rendering and paired presentation

- One native-size combined texture contains both source panels. XBGR uploads
  opaque R,G,B,255 bytes; XRGB uploads B,G,R,255. A shader handles the latter's
  channel interpretation without changing the source buffer on the CPU.
- One linear XRGB GBM surface contains two full-resolution output regions.
  Nearest-neighbour quads enlarge each source region by an integer and clear the
  remaining border to black. The `ds` layout uses 256×192 per panel; `earthbound`
  uses 256×224. Panel dimensions come from DRM, not board identifiers.
- `inspect` compares every rendered pixel against the integer-scaled pattern,
  including both source regions and borders. This verifies GPU rendering;
  physical screen order/orientation and scanout still need manual observation.
- Primary planes crop the two output regions at 1:1. Initial activation uses
  one atomic TEST_ONLY followed by one blocking modeset. Unsupported shared
  scanout is an error; there is no automatic second backend.
- Subsequent updates change both plane framebuffer IDs in one nonblocking,
  vblank-synchronized atomic commit. Version-three DRM events identify each CRTC.
  The previous GBM buffer is retained until both events arrive, in either order.
  There is at most one pending paired commit.
- `glFinish` explicitly completes rendering before KMS sees the buffer. Its
  cost is measured. Fence-based overlap is future work, not implied by this proof.
- Completion timestamps measure software-visible skew between outputs; a single
  atomic transaction does not guarantee physically phase-locked panels. The
  moving white markers on both panels represent the same synthetic frame.

## Comparison and recovery

The CPU mode uses the same source animation, row expansion/row replication and
border-only clears, then the existing full-resolution DRM upload/page-flip path.
It is a synthetic presentation reference, not an emulator benchmark. Pixel
conversion is scalar in this diagnostic; the player's XRGB converter uses SIMD.
Unchanged-panel caching is intentionally absent because the pattern moves.

Reports include generation, upload, rendering/finish, submission and completion
waits, mean/p95/max, process CPU time per frame, frames over 20 ms and paired
completion skew. CPU submission includes full-panel uploads. GPU rendering
includes EGL swap/GBM acquisition. Never compare the two labels as isolated
equivalent operations; compare total process CPU and the complete pipeline.

Normal exit restores the captured plane/connector/CRTC state before releasing
buffers. Cleanup errors are reported while remaining resources are still
released. If atomic restoration fails, outputs are disabled before freeing GPU
storage. An outer service-restoring wrapper is needed for fatal signals or a
watchdog kill; Nim defers cannot handle SIGKILL.

Run `nim r tests/test_drm_gpu_patterns.nim` for colours, both layouts, CPU output,
both completion orders and rejected duplicate/unexpected events. Existing
`tests/test_linux_drm.nim` covers the unchanged CPU DRM lifecycle.

## Device results

Pending physical validation. A successful build or advertised DRM format does
not establish hardware rendering, paired scanout acceptance or a performance win.
