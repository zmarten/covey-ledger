# Upland Hunter - User Guide

## What Is This?

Upland Hunter is a Garmin watch app for upland bird hunters. It runs on your Fenix 8, Fenix 7 Pro, Epix 2 Pro, or Forerunner 965 and gives you:

- **Flush marking** - Record bird flushes with species, quantity, and shot result
- **Downed bird locator** - Compass + distance to guide you back to downed birds
- **Dog tracking** - See your dogs' distance, direction, and status (requires Alpha/Astro handheld)
- **Map view** - All your markers on a real topo map
- **Session stats** - Flushes, shots, success rate, species breakdown
- **Activity recording** - Everything syncs to Garmin Connect as a hiking activity

---

## Getting Started

### Install the App

**Side-loading (development):**
1. Connect your watch to your computer via USB
2. Copy `UplandHunter.prg` to the `GARMIN/APPS/` folder on the watch
3. Disconnect and find "Upland Hunter" in your app list

**From Connect IQ Store (when available):**
1. Open the Garmin Connect IQ app on your phone
2. Search for "Upland Hunter"
3. Install to your watch

### First Launch

1. Launch the app from your watch's activity/app list
2. Wait for "GPS Ready" to appear (may take 10-30 seconds outdoors)
3. Press **SELECT** (middle-right button) to start a hunt
4. You're hunting! The timer starts and dog tracking activates

---

## Button Controls

All controls use physical buttons - no touchscreen needed. Works with gloves.

| Button | Main Screen | In Menus/Lists |
|--------|------------|----------------|
| **SELECT** (middle-right) | Start hunt / Mark flush | Confirm selection |
| **MENU** (long-press SELECT) | Open menu | - |
| **UP** (top-right) | - | Scroll up / Zoom in |
| **DOWN** (bottom-right) | - | Scroll down / Zoom out |
| **BACK** (bottom-left) | Exit app | Go back |

---

## Core Features

### Mark a Flush

When birds flush, press **SELECT** on the main screen. GPS is captured instantly.

1. **Select Species** - Scroll with UP/DOWN, press SELECT
2. **Quantity** - UP/DOWN to adjust count, press SELECT
3. **Shot Result** - Choose SHOT, MISSED, or NO SHOT
4. **Birds Down** (if SHOT) - How many downed, optional MARK BIRD for locator
5. **Confirmation** - Auto-dismisses in 2 seconds

The whole workflow takes under 10 seconds.

### Find a Downed Bird

From the Birds Down screen, select **MARK BIRD**:

1. **Point toward bird** - Aim your watch arm at where the bird fell, press SELECT
2. **Enter distance** - UP/DOWN adjusts by 5 yards. Quick-select: 10, 20, 30, 40
3. **Navigate** - Follow the arrow to the bird. Distance updates as you walk.
   - **GOT IT** - Bird retrieved, removes the marker
   - **HUNT** - Keep marker active, return to hunting

You can mark up to 10 downed birds simultaneously.

### Dog Tracking

Requires a Garmin Alpha or Astro handheld with "Broadcast Dog Data" enabled.

The main screen shows each dog's:
- Name and distance (color-coded: green < 30yd, yellow 30-100yd, red > 100yd)
- Status (moving, stationary, on point, treed)
- **ON POINT alert** - Red background + 3 strong vibrations

Dogs also appear on the map view with their estimated positions.

**Compatible handhelds:** Alpha 100, Alpha 200/200i, Alpha 300/300i, Astro 430

### Map View

Access via MENU > "Map View" during an active hunt.

- Shows your position, flush waypoints, downed bird markers, and dog positions
- Orange trail shows your walking path
- **UP/DOWN** - Manual zoom in/out (7 levels: 55m to 11km)
- **SELECT** - Toggle between auto-zoom (fit all markers) and manual zoom
- **BACK** - Return to main screen

### Session Stats

Access via MENU > "Session Stats" during an active hunt.

Shows: total flushes, shots taken, success rate (color-coded), birds downed, hunt duration, distance covered, and per-species breakdown. Scroll with UP/DOWN.

---

## Settings

Configure via the Garmin Connect Mobile app on your phone:

| Setting | Options | Default |
|---------|---------|---------|
| **Distance Units** | Yards / Meters | Yards |
| **GPS Update Rate** | Battery Saver (5s) / Standard (2s) / High Accuracy (1s) | Standard |
| **Vibration Alerts** | On / Off | On |
| **High Contrast Mode** | On / Off | Off |

**High Contrast Mode** switches to pure black backgrounds for maximum readability in bright sunlight. Also saves battery on AMOLED screens.

**GPS Update Rate** controls how often position data is processed. Battery Saver extends battery life for all-day hunts. High Accuracy gives the most precise waypoint placement.

---

## Tips for the Field

- **Start GPS early** - Launch the app a minute before you start hunting so GPS has time to lock
- **Battery Saver GPS** - Use Battery Saver mode for all-day hunts (8+ hours). Switch to High Accuracy when marking flushes if precision matters
- **High Contrast in sun** - Turn on High Contrast mode for bright conditions. Pure black background is much easier to read
- **Compass calibration** - Before using the downed bird locator, slowly rotate your wrist in a figure-8 pattern to calibrate the magnetometer. Avoid standing near your truck or gun
- **Dog tracker range** - ANT+ range to your Alpha/Astro handheld is typically 10-30 feet. Keep the handheld on your vest, not in the truck
- **Ending a hunt** - Press MENU > "End Hunt" to save the activity. It syncs to Garmin Connect on your next phone connection

---

## Data & Privacy

- All data stays on your watch and Garmin Connect account
- Waypoints are stored in the watch's Object Store (survives restarts)
- Activity tracks are saved as FIT files and sync to Garmin Connect
- No internet connection required during hunting - everything works offline
- Custom fields (flushes, birds down, shots) appear as Developer Fields in Garmin Connect

---

## Troubleshooting

**"Waiting for GPS..." won't go away**
- Make sure you're outdoors with a clear view of the sky
- Dense tree canopy can delay GPS lock. Wait 30-60 seconds.

**No dogs showing**
- Verify your Alpha/Astro has "Broadcast Dog Data" enabled in its settings
- Keep the handheld within 30 feet of your watch
- The watch searches for ~3 seconds before showing dog data

**Compass seems inaccurate**
- Calibrate by rotating your wrist in a figure-8
- Move away from metal objects (guns, trucks, belt buckles)
- The magnetometer works best when held level

**App crashes or freezes**
- Waypoint data is saved immediately on each flush, so no data is lost
- Restart the app and start a new hunt. Previous waypoints are preserved.

---

## Supported Devices

| Device | Screen | Status |
|--------|--------|--------|
| Fenix 8 Solar 51mm | 454x454 AMOLED | Primary target |
| Fenix 8 Solar 47mm | 416x416 AMOLED | Supported |
| Fenix 8 47mm | 416x416 AMOLED | Supported |
| Fenix 8 43mm | 390x390 AMOLED | Supported |
| Fenix 7 Pro | 260x260 MIP | Supported |
| Fenix 7X Pro | 280x280 MIP | Supported |
| Epix 2 Pro 42mm | 390x390 AMOLED | Supported |
| Epix 2 Pro 47mm | 416x416 AMOLED | Supported |
| Epix 2 Pro 51mm | 454x454 AMOLED | Supported |
| Forerunner 965 | 454x454 AMOLED | Supported |

---

## Version History

**v1.0** (February 2026)
- Initial release
- Full flush marking workflow (5 screens)
- Downed bird locator with compass navigation
- ANT+ dog tracking integration (Alpha/Astro)
- Map view with markers and breadcrumb trail
- Session statistics
- Activity recording with custom FIT fields
- Settings: units, GPS rate, haptic, high contrast
