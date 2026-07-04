---
name: music-workstation
description: Build and maintain the PulseForge Flutter mobile music workstation, including piano and guitar instruments, synthesis, dubstep, recording, MIDI, sequencer, mixer, mastering, project persistence, and audio export. Use for implementation, optimization, bug fixes, UI/UX changes, tests, or audio architecture work in this repository.
---

# Music Workstation

## Start

1. Read `docs/MUSIC_SOP.md`.
2. Trace event → scheduler → synthesis/sample → mixer → output.
3. Identify UI-isolate, audio-thread and render-isolate work.
4. Preserve project compatibility and unrelated changes.

## Architecture

- Keep models independent from Flutter and audio plugins.
- Keep synthesis, scheduling and voice ownership in services.
- Keep widgets declarative and inject engine interfaces.
- Run PCM generation, waveform and export outside the UI isolate.
- Persist project mutations locally before optional synchronization.
- Copy imported backing tracks into app-owned storage before playback and keep
  their player independent from the live-instrument voice pool.

## Audio safety and performance

- Bound polyphony with a fixed reusable voice pool; do not allocate one native
  player per tap. Reserve or mark a voice before awaiting stop/play so rapid
  concurrent taps cannot bypass the voice limit.
- Cache generated preview samples with a strict size cap and release every
  player, stream, timer and audio session.
- Play generated in-memory WAV `BytesSource` with the plugin's compatible
  default mode unless low-latency byte playback is verified on both platforms.
- Clamp gains; apply limiter before output; prevent NaN and denormal values.
- Avoid allocations in recurring sequencer ticks and audio callbacks.
- Make BPM changes reschedule cleanly without overlapping timers.
- Treat Bluetooth latency separately from speaker/wired latency.
- Never bundle unlicensed samples, presets or DSP code.
- Label generated falling lanes as a beat guide unless pitch/onset analysis has
  actually produced note-accurate transcription.

## Instrument UI

- Give every instrument its own playable interaction model; never collapse
  piano, guitar and dubstep into one generic pad grid.
- Piano uses a falling-lane beat guide above a touch keyboard. Guitar exposes
  chord triggers and six individually playable strings. Dubstep exposes 16
  performance pads and a tappable step-pattern grid.
- Built-in piano practice demos use deterministic note timelines with a
  four-beat lead-in. Falling tiles must align with playable key lanes, expose
  play/pause/replay, and score a hit only inside a bounded timing window.
- The workstation is landscape-only. Keep the instrument surface wide and
  prioritize playable keys, strings and pads over decorative vertical content.
- Keep primary navigation in the top-left app-bar dropdown; do not reserve a
  bottom navigation bar that reduces the landscape instrument surface.
- Preserve the shared backing-track transport when changing an instrument
  workspace so users can import a device track and play along.

## Processing documentation

Add `///` to public APIs and functions handling synthesis, samples, recording,
MIDI, scheduling, files, persistence, mixing, mastering or export. Document
constraints, side effects, thread/isolate, cancellation, failures and ownership.

## Reported errors

1. Inspect the exact call site, audio state and plugin version.
2. Explain root cause, impact, proposed change and validation.
3. Ask only `Yes/No` when confirmation is required.
4. After `Yes`, implement, test and record the durable rule here.

## Validate

Run formatting, `flutter analyze`, `flutter test`, then test physical-device
latency, multitouch, route changes, interruptions, backgrounding and thermal
load. Report unavailable checks explicitly.
