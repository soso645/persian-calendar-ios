# Vendored: Astronomy Engine (C)

Upstream: https://github.com/cosinekitty/astronomy
Commit: `61dc07020aaa6885d2c7f688a4d82beaf6edb9ef` (v2.1.19, 2023-12-14)
License: MIT (see `LICENSE-astronomy-engine.txt`)

This is the **same commit the Android app pins** in `gradle/libs.versions.toml`:

```toml
astronomy = "61dc07020aaa6885d2c7f688a4d82beaf6edb9ef" # is equal to v2.1.19
```

The Android app depends on the project's Kotlin port; this app uses the project's C port. Both are
maintained in the same repository from the same source of truth, so the ephemeris data and
algorithms are identical.

## Why not hand-port it to Swift?

The app calls 36 symbols from this library, but that subset transitively needs the full VSOP87
planetary ephemeris, the lunar theory, and the eclipse/rise-set search machinery — 10,675 lines in
the Kotlin edition, most of it dense coefficient tables. Retyping those by hand buys nothing and
risks a single-digit transcription error that no test would reliably catch. Vendoring the upstream
C keeps the numbers exactly right.

Swift code never touches this directly: `Core/Astronomy/Astronomy.swift` wraps it in an API shaped
like the Kotlin one the app screens were written against.

**Do not edit these two files.** To update, re-copy from upstream at a chosen commit and record it
here.
