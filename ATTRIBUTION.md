# Attribution

This project is a Swift/SwiftUI port of the Android **Persian Calendar** app. Almost all of the
behaviour, data and algorithms originate there; the licence is inherited accordingly.

## Upstream application

**Android Persian Calendar** — <https://github.com/persian-calendar/persian-calendar>
Version 10.2.0 (Kotlin + Jetpack Compose).
Copyright (C) 2012–2026 Android Persian Calendar Developers.
Licensed under the **GNU GPL v3 or later**. The full licence text is in [LICENSE](LICENSE); the
port is distributed under the same terms.

The Android source itself is deliberately **not vendored** in this repository. To compare the port
against it, clone the upstream repository at the `v10.2.0` tag.

## Logic libraries the port was checked against

These live in [`port-reference/`](port-reference) as read-only reference material and are the
fidelity source for the ported logic in `ios-app/PersianCalendar/Core/`.

| Library | Licence | Notes |
|---|---|---|
| [`persian-calendar/calendar`](https://github.com/persian-calendar/calendar) | GPL-2.0-or-later | Date conversion for Persian, Islamic, Gregorian and Nepali calendars. Origin: `code.google.com/p/mobile-persian-calendar` (GPLv2), heavily modified since. |
| [`persian-calendar/praytimes`](https://github.com/persian-calendar/praytimes) | LGPL-3.0 | Prayer-time astronomy. A Java port of [PrayTimes.js](http://praytimes.org/) by Hamid Zarrabi-Zadeh. |
| [`persian-calendar/calculator`](https://github.com/persian-calendar/calculator) | GPL-2.0-or-later | Expression evaluator used by the Converter screen. Its grammar is transcribed by hand in `Core/Calculator/CalculatorParser.swift`. |
| [`persian-calendar/qr`](https://github.com/persian-calendar/qr) | MIT | QR encoder, derived from [kazuhikoarase/qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) (MIT) and [ebraminio/headless_qr](https://github.com/ebraminio/headless_qr). |

## Data

- **`events.json`** — [`persian-calendar/events`](https://github.com/persian-calendar/events),
  released under **CC0 1.0 Universal**. Bundled at
  `ios-app/PersianCalendar/Resources/events.json`.
- **Map, tectonic-plate, time-zone and city data** (`worldmap.txt`, `tectonicplates.txt`,
  `timezones.txt`, `cities.json`, `districts.json`) — from the upstream app's resources, GPL-3.0-or-later.
- **Athan recordings** (`Resources/Sounds/*.caf`) — transcoded from the upstream app's `res/raw`
  audio, GPL-3.0-or-later.

## Vendored code inside the app

- **`ios-app/PersianCalendar/Core/Astronomy/CAstronomy/`** — `astronomy.c` / `astronomy.h` from
  [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy), commit `61dc0702` (v2.1.19),
  **MIT licence**. Copyright (c) Don Cross. The same commit is pinned by the Android app. The
  library's own README and LICENSE sit alongside the sources and are excluded from the app bundle.

## Everything else

The Swift port itself, the test suite and the documentation in this repository were written for
this project.
