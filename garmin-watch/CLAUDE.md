# Upland Hunter — Claude Code Project Instructions

## What You're Building

A Garmin Connect IQ watch app for upland bird hunters. It integrates with Garmin Alpha/Astro dog tracking handhelds via ANT+ and provides waypoint marking, bird tracking, and navigation features.

**Read `PRODUCT_BRIEF.md` in this directory for the full requirements.** It contains every feature specification, acceptance criteria, and technical constraint. Reference it constantly.

---

## Project Structure

```
UplandHunter/
├── CLAUDE.md                 # This file — your instructions
├── PRODUCT_BRIEF.md          # Full requirements — READ THIS FIRST
├── BUILD_LOG.md              # You maintain this — log every action
├── ISSUES.md                 # Track known issues, TODOs, limitations
├── source/
│   ├── UplandHunterApp.mc    # App entry point
│   ├── MainView.mc           # Main hunt screen
│   ├── MainDelegate.mc       # Main screen input handler
│   ├── FlushWorkflow/
│   │   ├── SpeciesSelectView.mc
│   │   ├── QuantityView.mc
│   │   ├── ShotResultView.mc
│   │   ├── BirdsDownView.mc
│   │   └── ConfirmationView.mc
│   ├── BirdLocator/
│   │   ├── BearingCaptureView.mc
│   │   ├── DistanceEntryView.mc
│   │   └── NavigationView.mc
│   ├── DogTracker/
│   │   ├── DogTrackerSensor.mc    # ANT+ communication
│   │   ├── DogData.mc             # Dog data model
│   │   └── DogTrackerMock.mc      # Mock data for development
│   ├── MapView/
│   │   └── HuntMapView.mc
│   ├── Stats/
│   │   └── SessionStatsView.mc
│   ├── Models/
│   │   ├── Waypoint.mc
│   │   ├── WaypointManager.mc
│   │   └── HuntSession.mc
│   └── Utils/
│       ├── CoordinateMath.mc      # Haversine, bearing calculations
│       ├── Constants.mc           # Colors, sizes, enums
│       └── DebounceHelper.mc
├── resources/
│   ├── strings.xml
│   ├── menus.xml
│   ├── settings.xml
│   └── drawables/
├── test/
│   ├── CoordinateMathTest.mc
│   ├── WaypointManagerTest.mc
│   └── FlushWorkflowTest.mc
├── manifest.xml
├── monkey.jungle
└── bin/                          # Build output
```

---

## Build & Test Commands

```bash
# Compile for Fenix 8 Solar
monkeyc -f monkey.jungle -o bin/UplandHunter.prg -d fenix8solar -y /path/to/developer_key.der

# Compile with warnings treated as errors (use this)
monkeyc -f monkey.jungle -o bin/UplandHunter.prg -d fenix8solar -w -y /path/to/developer_key.der

# Run in simulator (if connectiq tool is available)
connectiq && monkeydo bin/UplandHunter.prg fenix8solar

# Run unit tests
monkeyc -f monkey.jungle -o bin/UplandHunterTests.prg -d fenix8solar -t -y /path/to/developer_key.der
monkeydo bin/UplandHunterTests.prg fenix8solar

# Check file sizes (memory matters)
ls -la bin/UplandHunter.prg
```

**IMPORTANT:** If the `monkeyc` compiler is not on PATH, check these common locations:
- macOS: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-*/bin/monkeyc`
- Linux: `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-*/bin/monkeyc`
- Windows: `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-*\bin\monkeyc.bat`

If the SDK is not installed at all, create the source files anyway and note in BUILD_LOG.md that compilation needs to be done manually.

---

## Development Rules

### Process — Follow This Exactly

1. **Read PRODUCT_BRIEF.md first.** Understand the full architecture before writing any code.
2. **Build one feature at a time** following the phase order below.
3. **Compile after every feature.** Fix ALL errors and warnings before moving on.
4. **Log every action** to BUILD_LOG.md — what you built, what compiled, what failed, what you fixed.
5. **Run the quality gate** at the end of each phase before starting the next.
6. **Never skip ahead.** Phase 1 must be complete and compiling before you touch Phase 2.

### Phase Order

```
Phase 1: Core Foundation (MVP)
  1.1  Project scaffolding (manifest, permissions, app lifecycle, activity recording)
  1.2  Constants & utilities (colors, enums, coordinate math)
  1.3  Main screen layout (header, timer, placeholder dog list, bottom buttons)
  1.4  Mark Flush workflow (all 5 screens with full navigation)
  1.5  Waypoint data model and Object Store persistence
  1.6  FIT file integration (activity recording with waypoint data)
  1.7  Session statistics screen
  1.8  Settings infrastructure
  >> QUALITY GATE: Full compile, all workflows navigable, data persists across restart <<

Phase 2: Downed Bird Locator
  2.1  Compass bearing capture screen (magnetometer API)
  2.2  Distance entry screen
  2.3  Target point calculation (haversine + bearing)
  2.4  Navigation screen with real-time arrow and distance
  2.5  Multiple bird marker management (up to 10)
  2.6  Bird retrieved / back to hunt workflow
  >> QUALITY GATE: Bearing math unit tests pass, navigation updates correctly <<

Phase 3: Map View
  3.1  Garmin Map API integration
  3.2  Render user position and flush waypoints
  3.3  Render downed bird markers
  3.4  Auto-zoom and manual zoom
  3.5  List/map view toggle
  3.6  Breadcrumb trail (optional)
  >> QUALITY GATE: All markers render, zoom works, performance acceptable <<

Phase 4: ANT+ Dog Integration
  4.1  ANT+ Generic Channel setup and device discovery
  4.2  Dog data packet parsing (distance, direction, status)
  4.3  Dog name/color packet parsing
  4.4  Real-time dog list with distance color coding
  4.5  Point/treed alert system (haptic + visual)
  4.6  SensorDelegate for System 8 native pairing
  4.7  Connection state management
  4.8  Dog positions on map view
  >> QUALITY GATE: Compiles with ANT permissions, mock data flows correctly <<

Phase 5: Polish & Ship
  5.1  Battery optimization pass
  5.2  Error handling hardening
  5.3  Settings UI completion
  5.4  Additional device support
  5.5  User guide (README_USER.md)
  5.6  Store submission preparation
  >> QUALITY GATE: All features working, zero compiler warnings, docs complete <<
```

### Coding Standards

- **Comment everything.** Explain the "why", not just the "what". Zach is learning to code — make it educational.
- **Monkey C specifics:**
  - Use `var` for local variables, typed declarations for class members
  - Memory is precious — avoid unnecessary object creation
  - Use enums (constants) for species, shot results, connection states
  - Dispose of resources properly (Graphics.Dc, sensors, ANT channels)
  - Handle `null` defensively — sensors and GPS can return null at any time
- **Button debounce:** 500ms minimum on all interactive buttons. Hunters wear gloves.
- **Touch targets:** 60x60px minimum. Prefer larger.
- **Error handling:** Never crash. Catch everything. Show user-friendly messages.
- **Colors:** Use Constants.mc for all color values. Never hardcode hex in views.

### ANT+ Strategy

The ANT+ dog tracker protocol is NOT officially documented by Garmin. Here's the strategy:

1. **Build everything with mock data first** (DogTrackerMock.mc). Create a clean `DogTrackerInterface` that both mock and real implementations satisfy.
2. **When implementing real ANT+:**
   - Use `Ant.GenericChannel` — dog tracking is not a named ANT+ profile
   - The Alpha/Astro handheld broadcasts data when "Broadcast Dog Data" is enabled
   - 8-byte packets, 2 per dog (distance/direction/status), occasional name/color packets
   - Reference ekutter's work: https://ekutter.github.io
   - Search Garmin forums for "GenericChannel dog tracker" threads
3. **If you get stuck on the protocol**, leave the mock in place and document exactly what's needed in ISSUES.md. The mock allows all other features to be tested.

### Quality Gate Checklist

Run this between phases:

```
[ ] Compiles for fenix8solar with zero warnings
[ ] Every screen is reachable and has working back/cancel navigation
[ ] All button inputs work (physical buttons, not just touch)
[ ] Rapid button press test — no double entries
[ ] Data persists across app stop/restart
[ ] Memory usage logged (note in BUILD_LOG.md)
[ ] No hardcoded values — everything in Constants.mc or settings
[ ] All new code has comments explaining purpose
[ ] Unit tests pass (for math/data code)
[ ] BUILD_LOG.md updated with status
[ ] ISSUES.md updated with any known problems
```

---

## Critical Technical Notes

### Architecture
```
Watch ←— ANT+ —→ Alpha/Astro Handheld ←— VHF Radio —→ Dog Collars
```
The watch NEVER talks to collars directly. The handheld is the bridge.

### Manifest Permissions Required
```xml
<iq:permissions>
    <iq:uses-permission id="Positioning"/>
    <iq:uses-permission id="Sensor"/>
    <iq:uses-permission id="SensorHistory"/>
    <iq:uses-permission id="Ant"/>
    <iq:uses-permission id="FitContributor"/>
    <iq:uses-permission id="UserProfile"/>
</iq:permissions>
```

### Target Device
- Primary: fenix8solar (51mm AMOLED, 454x454px, System 8, API Level 5.0.1+)
- Build with SDK 8.x (minimum 7.4.3 for System 8 side-loading)

### Color Constants (define in Constants.mc)
```
COLOR_PRIMARY    = 0xEA580C  // Orange — actions, headers
COLOR_SUCCESS    = 0x16A34A  // Green — shot, close distance
COLOR_ALERT      = 0xDC2626  // Red — point alerts, far distance
COLOR_WARNING    = 0xEAB308  // Yellow — medium distance
COLOR_BG         = 0x1F2937  // Dark gray — backgrounds
COLOR_TEXT       = 0xFFFFFF  // White — primary text
COLOR_MUTED      = 0x9CA3AF  // Gray — secondary text
```

### Species Enum
```
SPECIES_PHEASANT = 0
SPECIES_QUAIL = 1
SPECIES_CHUKAR = 2
SPECIES_GROUSE_RUFFED = 3
SPECIES_GROUSE_SAGE = 4
SPECIES_GROUSE_SHARPTAIL = 5
SPECIES_WOODCOCK = 6
SPECIES_PRAIRIE_CHICKEN = 7
SPECIES_PARTRIDGE = 8
SPECIES_DOVE = 9
SPECIES_OTHER = 10
```

---

## BUILD_LOG.md Template

Start BUILD_LOG.md with this structure and update it after every action:

```markdown
# Upland Hunter Build Log

## Phase 1: Core Foundation

### 1.1 Project Scaffolding
- Status: NOT STARTED
- Date:
- Notes:
- Compiles: [ ]
- Issues:

### 1.2 Constants & Utilities
- Status: NOT STARTED
...
```

---

## If Things Go Wrong

- **Compiler not found:** Write all source files, note in BUILD_LOG.md, user will compile manually
- **Memory errors at runtime:** Reduce object allocations. Use primitive types. Lazy-load views.
- **ANT+ completely blocked:** Ship with mock data. Real integration can come later. The flush/waypoint/navigation features are valuable on their own.
- **Stuck on a Monkey C syntax issue:** Check https://developer.garmin.com/connect-iq/api-docs/ and https://developer.garmin.com/connect-iq/monkey-c/
- **FIT file format unclear:** Use `ActivityRecording` module, add custom fields via `FitContributor.Field`

---

## Remember

This is a personal project for Zach to use during hunting season. Prioritize:
1. **Reliability** — zero data loss, zero crashes
2. **Speed** — every interaction under 10 seconds with gloves
3. **Battery** — 8+ hours of active field use
4. **Functionality** — working features over perfect UI

Go build it. Start with Phase 1.1.
