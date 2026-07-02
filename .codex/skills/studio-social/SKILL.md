---
name: studio-social
description: Develop and review the Studio Social Flutter mobile app for camera effects, image/video editing, local-first projects, Firebase sync and notifications, project sharing, and social features. Use for any implementation, refactor, performance optimization, UI/UX work, database migration, media pipeline change, testing, or code review in this repository; enforce maintainability, responsive UI, data safety, and documentation of processing functions.
---

# Studio Social

## Start every task

1. Read `docs/SOP.md`; treat it as the project engineering contract.
2. Inspect existing models, interfaces, repositories and services before adding code.
3. Trace the complete data flow and identify UI-isolate, worker and native work.
4. State measurable acceptance criteria for behavior, failure and performance.
5. Preserve unrelated user changes and existing project-manifest compatibility.

## Implement in this order

1. Update domain models and versioned serialization.
2. Define or adjust repository/service interfaces.
3. Implement local persistence before cloud synchronization.
4. Implement Firebase/native adapters without leaking SDK types upward.
5. Connect feature state and UI last.
6. Add tests alongside the changed behavior.

Keep Flutter widgets declarative. Put business rules in domain/service code and
I/O in repositories. Inject dependencies through constructors. Never pass
`BuildContext` into data or service layers.

## Handle reported errors

When the user reports a build, runtime or test error:

1. Inspect the exact failing symbol, call site, dependency version and surrounding code.
2. Identify the root cause and distinguish it from downstream wrapper errors.
3. Explain the problem, impact, proposed code change and validation commands.
4. Do not modify implementation files until the user confirms the proposed fix,
   unless the user explicitly asks to fix immediately.
5. After confirmation, apply the smallest safe fix, run available checks and
   report any checks blocked by missing SDKs or devices.
6. When confirmation is required, ask for and accept a plain `Yes` or `No`;
   do not require the user to repeat a command phrase.

## Protect UI performance

- Keep CPU-heavy media, hashing, large JSON and file work off the UI isolate.
- Use native workers or isolates for rendering, thumbnails, waveform and checksum.
- Use proxy media for preview; load full resolution only for final export.
- Bound caches, decoder count, prefetch and concurrent transfers.
- Build long feed/timeline collections lazily and constrain rebuild regions.
- Add cancellation and backpressure to scrub, render and transfer operations.
- Target frames below 16.7 ms and immediate interaction feedback below 100 ms.
- Measure before and after optimization; record scenario, device and observed metric.

## Video editor conventions

- Use `video_player` only for native-backed preview, play/pause and seeking; it
  is not a final render engine.
- Store trim, split, speed and volume as validated `EditOperation` values and
  rebuild effective `VideoClipEdit` state from history. Never alter source files.
- Keep the decoder inside `VideoPreview`, dispose it with the widget lifecycle
  and expose only small playback commands to the editor screen.
- Timeline position updates use `ValueListenable` so decoder ticks do not
  rebuild the full editor. Import `package:flutter/foundation.dart` explicitly
  in files that declare `ValueListenable` fields; do not rely on Material
  library transitive exports.
- Never label simulated progress as export. Keep drafts locally until a native
  Android/iOS render adapter creates and verifies the output file.
- Keep the supplied two-level shelf categories (`Edit`, `Effects`, `Stickers`,
  `Audio`, `Text`) and expose only tools with working controls and preview.
- Copy picked audio into app-owned storage through `AudioImportService` before
  adding its path to project history; temporary picker paths are not draft-safe.
- Rebuild `VideoComposition` from operation history for filters, overlays,
  soundtrack, transitions and canvas ratio so undo/redo updates preview and
  timeline from one source of truth.
- Keep media plugin versions exact while the project targets Dart 3.9.2;
  caret upgrades previously selected packages requiring Dart 3.10.
- Represent labeled canvas ratios as records instead of keys in a const
  `Map<double, String>`; computed double keys cannot be const-evaluated.
- A blank video project must show an in-editor media CTA and hide edit tools
  until at least one durable video source has been imported.
- Source-list changes go through `EditHistory.replaceSourcePaths` so adding
  clips increments revision, autosaves and remains undoable.
- Never issue audio seek/pause/resume calls until an audio source is loaded;
  soundtrack failures must not prevent the video controller from playing.
- Store overlay positions as normalized canvas coordinates. Update drag preview
  in widget state and commit one history operation only when the gesture ends.

## Preserve UX

- Provide loading, empty, error, retry and offline states for every I/O flow.
- Keep drafts safe through crash, backgrounding, logout and network loss.
- Show explicit autosave/sync/conflict state; never silently overwrite conflicts.
- Explain permissions before requesting them and provide a Settings recovery path.
- Use 48×48 dp touch targets, semantic labels, scalable text and non-color cues.
- Make destructive actions undoable or confirm them.
- Phrase errors as: what happened, whether data is safe, and what to do next.

## Document processing functions

Add `///` documentation to every public API and every function that processes
media, files, network, database, authentication, synchronization, permissions,
retries, transactions or other non-obvious algorithms.

Document:

- purpose and result;
- non-obvious input/output constraints;
- file, database, network or state side effects;
- failures/domain errors;
- isolate/thread behavior and cancellation;
- performance limits and resource ownership when relevant.

Explain why private complex logic exists; do not narrate obvious statements.
Keep functions single-purpose, normally below 30 logical lines. Prefer named
configuration objects over boolean flags or more than four positional arguments.

When touching existing undocumented processing code, add or repair its
documentation within the same change.

## Enforce local-first and security

- Persist locally before enqueueing cloud work.
- Increment revision for each mutation and make queue operations idempotent.
- Keep both versions when equal revisions have divergent manifests.
- Stream large files, use resumable checksum-based upload and validate quota server-side.
- Use private storage and short-lived signed URLs.
- Enforce authorization with Firebase Security Rules and server validation; never trust client ownership,
  MIME, size, moderation status or share-link validity.
- Never expose Admin SDK credentials or log credentials, download URLs or private content.

## Validate before handoff

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For cloud changes, review Firestore and Storage Rules and test owner, stranger,
anonymous and blocked-user access in the emulator. For UI/media changes, verify lifecycle,
permission denial, offline behavior, cancellation, missing media and low storage
on representative physical devices.

Report exactly what was validated. If Flutter, native SDKs, Firebase or devices
are unavailable, state the unverified checks; never imply they passed.

## Definition of done

Do not mark work complete until:

- architecture boundaries and function documentation follow `docs/SOP.md`;
- UI remains responsive and long work is cancellable;
- user data survives expected failures;
- tests cover the success path and material failure paths;
- formatting, analysis and tests pass or blockers are explicitly reported;
- migrations are forward-only and project schema remains readable;
- no secret, unlicensed asset or generated build artifact is committed.
