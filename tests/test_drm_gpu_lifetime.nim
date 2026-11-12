include windy/platforms/linux/native/drm

var
  probe: GpuDisplay
  signalFd: cint
  eventOrder, events: seq[uint32]
  released: seq[pointer]
  restored: bool

proc releaseBuffer(surface, buffer: pointer) {.cdecl.} =
  ## Observe storage release without opening GBM or a physical display.
  doAssert not probe.pending and buffer notin released
  if buffer != cast[pointer](1): doAssert restored
  released.add buffer

proc allocate(): GpuAtomicRequest {.cdecl.} =
  ## Supply an opaque request for the real submission and cleanup paths.
  cast[pointer](1)

proc freeRequest(request: GpuAtomicRequest) {.cdecl.} =
  ## Accept the test-owned request.
  doAssert request == cast[pointer](1)

proc commit(fd: cint, request: GpuAtomicRequest, flags: uint32, data: pointer): cint {.cdecl.} =
  ## Queue both controller events or verify that restore precedes buffer release.
  if flags == GpuAllowModeset:
    doAssert not probe.pending and released == @[cast[pointer](1)]
    restored = true
  else:
    doAssert flags == (GpuAtomicNonblock or FlipEvent)
    doAssert data == cast[pointer](probe) and not probe.pending
    events.add eventOrder
    var signals = "FF"
    doAssert posix.write(signalFd, addr signals[0], signals.len) == signals.len

proc handleEvent(fd: cint, context: ptr EventContext): cint {.cdecl.} =
  ## Exercise the real completion callback in either controller order.
  var signal: char
  doAssert posix.read(fd, addr signal, 1) == 1
  doAssert events.len > 0
  let crtc = events[0]
  events.delete(0)
  let pairContext = cast[ptr GpuPairEvents](context)
  doAssert pairContext.version == 3
  pairContext.flip2(fd, 0, 0, 100, crtc, cast[pointer](probe))
  if not probe.pair.ready:
    let count = released.len
    var rejected = false
    try: probe.gpuRetireFrame()
    except IOError: rejected = true
    doAssert rejected and released.len == count

proc main() =
  ## Keep front, queued and rendering storage alive until paired completion.
  for order in [@[69'u32, 70], @[70'u32, 69]]:
    var pipeFds: array[2, cint]
    doAssert pipe(pipeFds) == 0
    signalFd = pipeFds[1]
    eventOrder = order
    events = @[]
    released = @[]
    restored = false
    let
      front = cast[pointer](1)
      queued = cast[pointer](2)
      rendering = cast[pointer](3)
    probe = GpuDisplay(armed: true, pending: true,
      display: DrmDisplay(fd: pipeFds[0], api: DrmApi(handleEvent: handleEvent)),
      gpu: GpuApi(gbm_surface_release_buffer: releaseBuffer),
      atomic: GpuAtomicApi(alloc: allocate, free: freeRequest, gpuCommit: commit),
      pair: GpuFlipPair(crtcs: [69'u32, 70]),
      front: front, queued: queued, locked: @[front, queued, rendering])
    events.add order
    var signals = "FF"
    doAssert posix.write(signalFd, addr signals[0], signals.len) == signals.len
    probe.gpuWaitPair()
    doAssert released.len == 0 and not probe.pending
    probe.gpuRetireFrame()
    doAssert probe.front == queued and probe.queued == nil
    doAssert released == @[front] and probe.locked == @[queued, rendering]
    probe.gpuRetireFrame()
    doAssert released == @[front]
    probe.gpuSubmit(3)
    probe.queued = rendering
    probe.close()
    doAssert restored and events.len == 0
    doAssert released == @[front, queued, rendering] and probe.locked.len == 0
    probe.close()
    doAssert released.len == 3
    doAssert posix.close(pipeFds[0]) == 0
    doAssert posix.close(pipeFds[1]) == 0

main()
