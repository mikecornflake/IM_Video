# Inspector Mike Video Player

**Inspector Mike Video Player** is a single and multi-channel video
player designed for offshore inspection and ROV operations.

Originally developed to provide synchronised playback of multiple DVR
recordings, IM_Video has evolved into a general-purpose inspection video
player built around the excellent **mpv** media engine.

## Features

- Browse video by folder hierarchy
- Open associated Anomaly and Stills folders directly from the 
application
- Support for MPV-based video playback within the application:
  - Play one to four synchronised video channels simultaneously
  - Synchronous playback controls (Play, Pause, Seek)
  - Automatic layout of multiple video channels
  - Variable speed playback
  - Mouse wheel seek (±3 seconds, ±1 seconds with Ctrl, ±6 seconds 
with Shift)
  - Spacebar pause/resume
  - Frame/image capture
- Multichannel video is currently treated as a set of video files
  in the same folder starting within 10 seconds of each other.
  Awareness of video naming protocols from various subsea
  inspection packages. This allows start date/time to be
  determined.
  
## Licence

This code and executable are released under GPL-3.0.

You are free to use, distribute and modify this software, 
but please keep the acknowledgements intact.

## Build information

This project is currently developed and tested using:

- Lazarus Trunk (4.8)
- Free Pascal Compiler 3.2 Fixes Branch

### Required Packages

The following packages are required from InspectorMike Common:

- IM_units.lpk
- IM_forms.lpk
- IM_forms.media.lpk
- IM_forms.media.mpv.lpk

Repository:

https://github.com/mikecornflake/InspectorMike-common

Install the following package from the Lazarus 
Online Package Manager (OPM):

- TurboPowerIPro.lpk

### Video Playback

Video playback is provided by UW_MPVPlayer:

https://github.com/URUWorks/UW_MPVPlayer

Required package:

- uwmpvplayer.lpk

### MPV Runtime

A copy of `libmpv-2.dll` must be available at runtime.

The DLL may be located in any of the following locations:

- A directory included in the system `PATH`
- The same directory as `IM_Video.exe`
- An `mpv\x86_64` subdirectory beneath the application folder

For example:

```text
IM_Video.exe
libmpv-2.dll
```
or
```text
IM_Video.exe
mpv\x86_64\libmpv-2.dll
```

## Acknowledgements

Many thanks to the developers of:

- Lazarus
- Free Pascal
- mpv
- URUWorks UW_MPVPlayer

### mpv

This project uses the mpv DLL for video playback:

https://github.com/mpv-player/mpv

The Free Pascal mpv wrapper is by URUWorks:

https://github.com/URUWorks/UW_MPVPlayer

### FatCow Hosting Icons

The application uses icons from the excellent **FatCow Hosting Icons**
collection.

https://www.softicons.com/toolbar-icons/fatcow-hosting-icons-by-fatcow

Many thanks to FatCow for making these icons freely available.

# FAQ

## Who am I?

This project is developed by Mike Thompson, 
a CSWIP 3.4U Subsea Inspection Engineer and 
former professional Delphi developer who 
regularly works with offshore inspection 
video from multiple contractors.

- Inspector Mike 2.0 Pty Ltd
- https://wiki.freepascal.org/User:Mike.cornflake
- https://github.com/mikecornflake
- mike.cornflake@gmail.com

## Why release this?

Commercial inspection DVR packages often provide 
limited facilities for end clients to review 
multiple synchronised video channels. This 
project aims to make inspection video easier 
to browse, review and analyse, while remaining 
portable and suitable for offshore use.

## Is this free?

Yes.

Just keep the acknowledgements.

## Can I modify it?

Yes.

Please keep the acknowledgements and consider 
offering useful changes back to Mike Thompson, 
URUWorks, or the mpv team, depending on 
which part of the code you modify.
