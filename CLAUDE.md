{\rtf1\ansi\ansicpg1252\cocoartf2907
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 You are porting an Android app to a native iOS app. Work fast and autonomously \'97 \
don't ask me to confirm each step, just report at the checkpoints.\
\
CONTEXT\
- This folder contains: (1) a downloaded GitHub repo of the Android source app, \
  (2) a .txt file somewhere in here with CLI/build instructions. Find and read both first.\
- Source: Kotlin + Jetpack Compose. Target: Swift 6 + SwiftUI, iOS 17+, iPhone only.\
- Skip anything Wear OS, Android widgets/tiles, or Play Services specific.\
- I'm on an M5 MacBook Pro with Xcode installed.\
\
PHASE 0 \'97 RECON (be quick, max ~10 min of tool calls)\
1. Map the repo: modules, entry points, screens, data layer, any pure-logic modules.\
2. Read the .txt file and note anything that affects build/run.\
3. Write PORT_PLAN.md: screen inventory, data model inventory, Android APIs that need \
   an iOS equivalent (SharedPreferences\uc0\u8594 UserDefaults, Room\u8594 SwiftData, WorkManager\u8594 \
   BGTaskScheduler, Compose Navigation\uc0\u8594 NavigationStack, etc.), and a phase list.\
Then STOP and show me PORT_PLAN.md. Wait for my go-ahead.\
\
PHASE 1 \'97 SCAFFOLD\
- Create ./ios-app/ with an Xcode project (SwiftUI lifecycle, no storyboards).\
- Set up the folder structure from the plan. Must build clean with:\
  xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' build\
- Checkpoint: build passes.\
\
PHASE 2 \'97 PURE LOGIC FIRST\
- Port all framework-independent logic (algorithms, formatters, calculations, models) \
  before any UI. These are the highest-fidelity translations \'97 get them exactly right.\
- Write XCTest cases for each, ideally mirroring the Android unit tests if they exist.\
- Checkpoint: all tests pass. Show me the test output.\
\
PHASE 3 \'97 DATA + PERSISTENCE\
- Port storage, settings, and any local DB. Use SwiftData or UserDefaults as appropriate.\
- Checkpoint: build + tests pass.\
\
PHASE 4 \'97 UI, SCREEN BY SCREEN\
- Port screens in dependency order, starting with the main screen.\
- Match behaviour and layout intent, not pixel-for-pixel Material Design \'97 use native \
  iOS idioms (NavigationStack, .sheet, SF Symbols, system colors, Dynamic Type).\
- Support light/dark mode and RTL if the source app does.\
- After EACH screen: build, then STOP and give me a one-paragraph summary. Don't \
  batch multiple screens without checking in.\
\
RULES\
- Never leave TODO stubs in place of real logic. If something can't be ported, list it \
  in PORT_PLAN.md under "Deferred" and tell me.\
- Run xcodebuild after every meaningful change. Fix warnings as you go.\
- Prefer editing files directly over showing me diffs in chat.\
- Keep a running PORT_PROGRESS.md so we can resume if the session dies.\
- Use parallel tool calls when reading/searching \'97 speed matters here.\
\
Start with Phase 0 now.}