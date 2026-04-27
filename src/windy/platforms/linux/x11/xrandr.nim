import x, xlib

const libXrandr* =
  when defined(macosx):
    "libXrandr.dylib"
  else:
    "libXrandr.so(|.2)"

type
  XRRScreenResources* = object
    timestamp*: Time
    configTimestamp*: Time
    ncrtc*: cint
    crtcs*: ptr UncheckedArray[RRCrtc]
    noutput*: cint
    outputs*: ptr UncheckedArray[RROutput]
    nmode*: cint
    modes*: pointer

  XRRCrtcInfo* = object
    timestamp*: Time
    x*, y*: cint
    width*, height*: cuint
    mode*: RRMode
    rotation*: cushort
    noutput*: cint
    outputs*: ptr UncheckedArray[RROutput]
    rotations*: cushort
    npossible*: cint
    possible*: ptr UncheckedArray[RROutput]

  XRROutputInfo* = object
    timestamp*: Time
    crtc*: RRCrtc
    name*: cstring
    nameLen*: cint
    mmWidth*, mmHeight*: culong
    connection*: cushort
    subpixelOrder*: cushort
    ncrtc*: cint
    crtcs*: ptr UncheckedArray[RRCrtc]
    nclone*: cint
    clones*: ptr UncheckedArray[RROutput]
    nmode*: cint
    npreferred*: cint
    modes*: ptr UncheckedArray[RRMode]

  RRCrtc* = culong
  RROutput* = culong
  RRMode* = culong

const
  RR_Connected* = 0
  RR_Disconnected* = 1
  RR_UnknownConnection* = 2

{.push, cdecl, dynlib: libXrandr, importc.}

proc XRRGetScreenResourcesCurrent*(d: Display, w: Window): ptr XRRScreenResources
proc XRRGetCrtcInfo*(d: Display, res: ptr XRRScreenResources, crtc: RRCrtc): ptr XRRCrtcInfo
proc XRRGetOutputInfo*(d: Display, res: ptr XRRScreenResources, output: RROutput): ptr XRROutputInfo
proc XRRFreeScreenResources*(res: ptr XRRScreenResources)
proc XRRFreeCrtcInfo*(info: ptr XRRCrtcInfo)
proc XRRFreeOutputInfo*(info: ptr XRROutputInfo)

{.pop.}
