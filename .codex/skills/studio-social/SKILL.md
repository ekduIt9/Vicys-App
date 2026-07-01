---
name: studio-social
description: Develop and review the Studio Social Flutter mobile app for camera effects, image/video editing, local-first projects, Supabase sync, project sharing, and social features. Use for any implementation, refactor, performance optimization, UI/UX work, database migration, media pipeline change, testing, or code review in this repository; enforce maintainability, responsive UI, data safety, and documentation of processing functions.
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
4. Implement Supabase/native adapters without leaking SDK types upward.
5. Connect feature state and UI last.
6. Add tests alongside the changed behavior.

Keep Flutter widgets declarative. Put business rules in domain/service code and
I/O in repositories. Inject dependencies through constructors. Never pass
`BuildContext` into data or service layers.

## Protect UI performance

- Keep CPU-heavy media, hashing, large JSON and file work off the UI isolate.
- Use native workers or isolates for rendering, thumbnails, waveform and checksum.
- Use proxy media for preview; load full resolution only for final export.
- Bound caches, decoder count, prefetch and concurrent transfers.
- Build long feed/timeline collections lazily and constrain rebuild regions.
- Add cancellation and backpressure to scrub, render and transfer operations.
- Target frames below 16.7 ms and immediate interaction feedback below 100 ms.
- Measure before and after optimization; record scenario, device and observed metric.

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
- Enforce authorization with RLS and server validation; never trust client ownership,
  MIME, size, moderation status or share-link validity.
- Never expose service-role keys or log credentials, signed URLs or private content.

## Validate before handoff

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For schema changes, review every table with RLS enabled and test owner, stranger,
anonymous and blocked-user access. For UI/media changes, verify lifecycle,
permission denial, offline behavior, cancellation, missing media and low storage
on representative physical devices.

Report exactly what was validated. If Flutter, native SDKs, Supabase or devices
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
