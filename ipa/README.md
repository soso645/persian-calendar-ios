# PersianCalendar.ipa

An installable iPhone build of the ported app, packaged from the Xcode project in
`../ios-app`.

| | |
|---|---|
| File | `PersianCalendar.ipa` (1.4 MB) |
| Bundle ID | `com.byagowi.persiancalendar.ios` |
| Version | 10.2.0 (build 1) |
| Minimum iOS | 17.0 |
| Architecture | arm64 (device, not simulator) |
| Signing | **unsigned** — ad-hoc signature only |
| SHA-256 | `7b0c2cd4f7871b7558f735f1798a396af36a7a58d43c522baef5ecb1ba82780c` |

## It is unsigned

There is no Apple Developer certificate on the machine that built this, so the app was
archived with `CODE_SIGNING_ALLOWED=NO` and given an ad-hoc signature. iOS will not install
it by AirDrop, Finder, or a plain `.ipa` tap — it has to be re-signed for your device first.
Nothing inside the app depends on the signature; it is the same binary the simulator ran.

## Installing

**Sideloadly** (macOS/Windows, free Apple ID) — drag the `.ipa` in, enter your Apple ID,
install. Free accounts sign for 7 days and up to 3 apps, then it must be re-signed.

**AltStore / SideStore** — same free-account limits, refreshes over Wi-Fi.

**Xcode** (no IPA needed) — open `ios-app/PersianCalendar.xcodeproj`, select your team under
Signing & Capabilities, and Run on a connected iPhone. This is the easiest route if you have
a Mac and a cable.

**TrollStore** — only on iOS versions with the CoreTrust bug; it installs unsigned IPAs
permanently, no Apple ID.

With a paid developer account, re-sign with your distribution certificate (or archive and
export from Xcode) if you want a longer-lived install.

## Rebuilding

```sh
cd ../ios-app
./make-ipa.sh                 # -> ipa/PersianCalendar.ipa
OUT_DIR=/tmp ./make-ipa.sh    # somewhere else
```

The script archives Release for `generic/platform=iOS`, ad-hoc signs, and zips
`Payload/PersianCalendar.app`. It also passes `-disable-sandbox` to Swift and keeps compiler
caches inside `ios-app/build/`; without those, Xcode's macro plugin server fails under this
checkout's file sandbox with `swift-plugin-server produced malformed response`.

## Verifying the payload

```sh
unzip -l PersianCalendar.ipa | head
unzip -p PersianCalendar.ipa Payload/PersianCalendar.app/Info.plist > /tmp/Info.plist
plutil -p /tmp/Info.plist
```
