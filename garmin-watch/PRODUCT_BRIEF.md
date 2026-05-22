# Upland Hunter — Garmin Watch App Product Brief v2.0

**Version:** 2.0 | **Updated:** February 2026
**Target Device:** Garmin Fenix 8 Solar (51mm AMOLED, 454x454px)
**SDK:** Connect IQ SDK 8.x (System 8) | **API Level:** 5.0.1+
**Language:** Monkey C
**Primary User:** Upland bird hunter with Garmin Alpha/Astro dog tracking system
**Project Owner:** Zach | **Priority:** Medium-high (personal project for hunting season)

---

## 1. Project Overview

Build a Garmin Connect IQ watch application for upland bird hunters that integrates with Garmin Alpha/Astro dog tracking handheld systems via ANT+ and provides waypoint marking, bird tracking, and navigation features.

### CRITICAL ARCHITECTURE NOTE

The watch does NOT connect directly to dog collars. The data flow is:

```
Watch ←— ANT+ —→ Alpha/Astro Handheld ←— VHF Radio —→ Dog Collars
```

The Garmin Alpha/Astro handheld communicates with collars via VHF radio, then broadcasts aggregated dog data to the watch via ANT+. The handheld must have "Broadcast Dog Data" enabled in its settings. This is a proven architecture — existing Connect IQ apps (e.g., ekutter's Dog Tracker) already do this successfully using Generic ANT Channels.

**Removed from scope:** Beep/Tone collar control. Collar stimulation and tone commands are sent from the handheld to collars via VHF radio, not ANT+. The watch cannot control collars. This is a hardware limitation.

---

## 2. Core Requirements

### 2.1 Dog Tracking Integration

**Priority:** CRITICAL

Connect to Garmin Alpha/Astro handheld via ANT+ Generic Channels. The handheld broadcasts dog data in 8-byte ANT+ packets (2 packets per dog for distance/direction/status, plus occasional packets for name and color).

**Data to Display Per Dog:**

- Dog name (from ANT+ name packets)
- Distance in yards (from handheld's calculated distance)
- Compass direction (degrees and cardinal: N, NE, E, SE, S, SW, W, NW)
- Status: moving, stationary, on point, treed, GPS lost, comm lost
- Battery level (%) if available in ANT+ data
- Signal quality indicator
- Last update timestamp

**UI Specifications:**

- Support display of up to 20 dogs, optimize UI for 2–4 simultaneous
- Large rotating navigation arrow using Garmin's built-in compass
- Distance color coding:
  - Green (#16A34A): < 30 yards
  - Yellow (#EAB308): 30–100 yards
  - Red (#DC2626): > 100 yards
- Visual alert when dog goes on point: red background with pulsing animation
- Haptic vibration on point/treed alerts

**Compatible Handhelds:** Alpha 100, Alpha 200/200i, Alpha 300/300i, Astro 430

**Acceptance Criteria:**

- Watch discovers and connects to Alpha/Astro handheld within 10 seconds
- Dog positions update with < 2 second latency
- Point/treed alerts trigger haptic vibration within 1 second
- Graceful handling of signal loss ("comm lost" / "GPS lost" states)
- Works with all listed handheld models

---

### 2.2 Mark Flush Feature

**Priority:** HIGH
**Trigger:** Physical watch button (user configurable, suggest bottom-right button)

The entire workflow must complete in under 10 seconds for an experienced user.

**Screen 1 — Species Selection:**
Grid of buttons showing common species. Track "recent species" and show them first. Species list:
- Pheasant
- Quail
- Chukar
- Grouse (Ruffed)
- Grouse (Sage)
- Grouse (Sharp-tailed)
- Woodcock
- Prairie Chicken
- Partridge (Hungarian)
- Dove
- Other

**Screen 2 — Quantity:**
Large number display with +/- buttons. For quail/partridge: optional covey size selector (8, 12, 16, 20, 25, Custom).

**Screen 3 — Shot Result:**
Two large buttons: "SHOT" (green) / "MISSED" (gray). "NO SHOT" option for flushes where no shot was taken.

**Screen 4 — Birds Down (if SHOT selected):**
Count of birds downed (capped at quantity flushed) with +/- buttons. Hot button: "MARK BIRD LOCATION" triggers Downed Bird Locator (Feature 2.3). "SAVE WAYPOINT" button.

**Screen 5 — Confirmation:**
Show GPS coordinates and timestamp. Auto-dismiss after 2 seconds, return to main screen. Haptic confirmation buzz.

**Data Storage per Waypoint:**
- GPS coordinates (lat/long) — captured at moment of flush, NOT confirmation
- Timestamp
- Species (enum)
- Quantity flushed
- Quantity downed
- Shot result (shot / missed / no_shot)
- Covey size (nullable, for quail/partridge)
- Dog on point (boolean + dog name if available)

**Storage Format:**
- Object Store API for in-app persistence across sessions
- FIT file format for Garmin Connect integration
- Export to GPX via Garmin Connect Mobile companion

**Acceptance Criteria:**

- Complete flush-to-confirmation in < 10 seconds
- GPS coordinates captured at moment of flush (not confirmation)
- Waypoint persists through activity pause/resume
- No double-entries from rapid button presses (debounce 500ms)
- Species MRU (most recently used) correctly reorders after 3+ uses

---

### 2.3 Downed Bird Locator

**Priority:** HIGH
**Trigger:** Hot button on Birds Down screen OR manual activation from main screen

**Screen 1 — Point Direction:**
Visual compass with rotating arrow. User physically points watch toward downed bird. Capture compass bearing on "NEXT" press. Show current bearing in degrees and cardinal direction. Include instruction text: "Point toward bird, press NEXT."

**Screen 2 — Distance Entry:**
Manual distance entry (default: 15 yards). +/- buttons (increment by 5 yards). Quick select buttons: 10, 20, 30, 40 yards.

**Screen 3 — Navigation:**
Large rotating arrow showing relative direction to marked bird. Distance to bird updates in real-time as user walks. Cardinal direction label. Two buttons: "BIRD RETRIEVED" (removes marker) and "BACK TO HUNT" (keeps marker active).

**Technical Requirements:**

- Use device GPS + magnetometer (compass) to calculate bearing
- Calculate target point from: current GPS position + bearing + distance
- Use haversine formula for coordinate math
- Update distance/direction continuously as user moves toward bird
- Support multiple simultaneous downed bird markers (up to 10)
- Display markers on map view with pulsing orange icons

**Acceptance Criteria:**

- Bearing capture accurate to ±5 degrees
- Distance calculation accurate to ±10 meters (GPS limitation)
- Navigation arrow updates smoothly (< 500ms refresh)
- Marker persists if user returns to main hunt screen
- Multiple birds can be marked and navigated to sequentially

---

### 2.4 Map View

**Priority:** MEDIUM
**Toggle:** Between list view and map view via button or swipe gesture.

**Map Display:**

- Use Garmin's built-in map rendering API
- Topo or hybrid satellite view (device-dependent)
- User position: blue dot, centered
- Dog positions: green (moving) / red (stationary) dots with first letter of dog name
- Flush waypoints: green bird icon (shot) / gray bird icon (missed)
- Downed bird markers: orange pulsing dot
- Breadcrumb trail: optional, configurable in settings
- Auto-zoom to fit all active markers, with manual zoom override

**Acceptance Criteria:**

- Map renders within 1 second of view switch
- All active markers display correctly
- Pan/zoom responsive (< 200ms frame update)
- Map does not significantly increase battery drain vs. list view

---

### 2.5 Session Statistics

**Priority:** MEDIUM
**Access:** From main screen via dedicated button.

**Display:**

- Total flushes (count)
- Shot attempts (count)
- Success rate (birds downed / shots taken, as percentage)
- Total birds downed (count)
- Breakdown by species (species name: flushed / downed)
- Hunt duration (elapsed time)
- Distance covered (miles/km)

**Data Lifecycle:**

- Calculate from saved waypoints during current activity
- Reset when activity ends
- Save to FIT activity summary on activity completion
- Historical season stats viewable in Garmin Connect

---

### 2.6 Settings & Configuration

**Priority:** LOW (but configure early for flexibility)
**Access:** Via Garmin Connect Mobile app (phone) and on-watch settings menu.

- Units: yards or meters
- Color scheme: standard or high-contrast (for bright sunlight)
- Auto-save waypoints: on/off
- Default species list order (drag to reorder in phone app)
- Button mappings for Mark Flush trigger
- Map preferences: show/hide breadcrumb trail, marker types, auto-zoom
- Dog display: max visible count, sort order (distance/name/status)
- Alerts: haptic on/off, point alert style (continuous/single buzz)
- GPS polling frequency: battery saver (5s) / standard (2s) / high accuracy (1s)

---

## 3. Technical Specifications

### 3.1 Development Environment

| Component | Specification |
|-----------|---------------|
| Language | Monkey C (Connect IQ) |
| SDK | Connect IQ SDK 8.x (System 8) — latest stable |
| Target API Level | 5.0.1+ (Fenix 8 Solar requires SDK 7.3.0 minimum) |
| IDE | VS Code with Monkey C extension (recommended for System 8 features) |
| Primary Device | Fenix 8 Solar (51mm AMOLED, 454x454px) |
| Secondary Devices | Fenix 7 series, Epix series, Forerunner 965, Tactix 8 |
| Minimum Screen | 260x260px (scale up for larger displays) |

### 3.2 Device Capabilities Required

- GPS (position tracking)
- Compass / Magnetometer (bearing calculation for downed bird locator)
- ANT+ with Generic Channel support (dog tracker communication)
- Physical buttons (Mark Flush trigger — cannot rely on touch alone with gloves)
- Activity Recording (FIT file integration)
- Object Store (persistent waypoint data)
- Haptic / Vibration motor (alerts)

### 3.3 ANT+ Dog Tracker Protocol

Based on research from existing Connect IQ dog tracker implementations and Garmin forum developer discussions:

- Communication is via ANT+ Generic Channels (not a named ANT+ device profile)
- Alpha/Astro handheld broadcasts 8-byte packets
- Each dog requires 2 data packets for distance, direction, and status
- Additional packets carry dog name and collar color
- Packet rate is multiple per second — all dogs cycle through quickly
- ANT+ apps require additional Garmin store review by the ANT team
- Must register with thisisant.com for protocol documentation access

**Reference Implementation:** ekutter's "Dog Tracker" app on the Connect IQ store is an existing, proven implementation. Study its approach and references from the developer's GitHub (ekutter.github.io).

### 3.4 Data Storage Strategy

- Object Store API: primary persistent storage for waypoints within the app
- FIT file format: write waypoint and session data for Garmin Connect sync
- Optimize for hundreds of waypoints per season
- Implement data migration strategy for app updates
- Purge old data configurable (end of season auto-archive)

### 3.5 Battery Optimization

- Configurable GPS polling: 1s (high accuracy), 2s (standard), 5s (battery saver)
- Reduce compass polling when not in navigation mode
- Efficient screen refresh — only redraw changed elements
- Low-power mode: dim screen, reduce polling during inactive periods
- Target: 8+ hours active hunting use
- Background mode considerations for multi-day hunts

### 3.6 System 8 Considerations

- On System 8 devices, ANT sensors searching outside the native pairing flow trigger a security warning — implement SensorDelegate for native pairing
- Side-loaded apps for System 8 devices must be built with SDK 7.4.3+
- Leverage extended code space (16MB paged) for larger app footprint
- Use new Notifications API for background alerts (dog on point while app not focused)

---

## 4. User Interface Design Guidelines

### 4.1 Design Principles

- **Speed over beauty:** hunters need information in < 2 seconds
- **Glove-friendly:** minimum touch target 60x60px with generous padding
- **Sunlight readable:** high contrast, bold text, avoid fine details
- **Physical button primary:** every critical action accessible via buttons, touch is supplemental
- **Minimal screen depth:** no action should require > 4 taps from main screen

### 4.2 Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Primary / Action | #EA580C | Headers, action buttons, active state |
| Success | #16A34A | Shot birds, close distance, success indicators |
| Alert / Danger | #DC2626 | Point alerts, downed bird markers, far distance |
| Warning | #EAB308 | Medium distance, caution indicators |
| Background | #1F2937 | Dark backgrounds for AMOLED efficiency |
| Text | #FFFFFF | All primary text on dark backgrounds |
| Muted | #9CA3AF | Secondary text, disabled states |

### 4.3 Typography & Layout

- Use Garmin system fonts exclusively
- Critical data (distance, direction): largest available bold font
- Secondary data (dog name, timestamp): medium font
- Labels and instructions: small font
- Consistent header bar on all sub-screens with back navigation
- Fast, minimal animations — hunters need speed, not transitions

### 4.4 Accessibility

- High contrast mode option (pure black/white for bright sunlight)
- Large text scaling mode
- Haptic feedback for all important events (configurable)
- Audio tones: optional, off by default (noise discipline while hunting)

---

## 5. Development Phases

### Phase 1: Core Foundation (MVP)

**Goal:** Working app with flush marking and waypoint storage. No ANT+ yet.

- Project scaffolding: manifest, permissions, app lifecycle
- Main screen layout with placeholder dog list (manual/static entries)
- Mark Flush workflow (all 5 screens): species → quantity → result → birds down → confirmation
- GPS waypoint capture and Object Store persistence
- Session statistics screen (calculated from stored waypoints)
- Basic FIT file recording (activity start/stop)
- Button mapping and input handling
- Settings infrastructure (units, species order)

**Test:** Full flush workflow, waypoint persistence across app restart, stats calculation.

### Phase 2: Downed Bird Locator

**Goal:** Compass-based bird marking and navigation.

- Compass bearing capture screen
- Distance entry screen with quick-select buttons
- Target point calculation (GPS + bearing + distance)
- Real-time navigation arrow and distance display
- Multiple simultaneous bird markers (up to 10)
- Bird retrieved / back to hunt workflow

**Test:** Bearing math, target point calculation, navigation updates with simulated position changes.

### Phase 3: Map View

**Goal:** Visual map with all markers.

- Garmin Map API integration
- Render user position, flush waypoints, downed bird markers
- Auto-zoom to fit markers
- Toggle between list and map views
- Breadcrumb trail (optional)

**Test:** Map rendering performance, marker placement accuracy, zoom behavior.

### Phase 4: ANT+ Dog Integration

**Goal:** Live dog tracking from Alpha/Astro handheld.

- ANT+ Generic Channel setup and device discovery
- Parse dog data packets (distance, direction, status, name, color)
- Real-time dog list with distance color coding
- Point/treed alert system (haptic + visual)
- SensorDelegate for System 8 native pairing flow
- Connection state management (searching, connected, comm lost)
- Dog positions on map view

**Test:** Requires ANT+ USB stick in simulator AND/OR field testing with actual Alpha/Astro handheld.

### Phase 5: Polish & Ship

**Goal:** Production-ready for hunting season.

- Battery optimization pass (profiling and tuning)
- Settings UI completion (Garmin Connect Mobile integration)
- Error handling hardening (GPS loss, compass calibration, ANT+ dropout)
- FIT file data completeness (session summary, waypoint export)
- Additional device support (Fenix 7, Epix, Forerunner 965)
- User guide documentation
- Connect IQ store submission (including ANT team review)
- Field testing during actual hunts

---

## 6. Testing Requirements

### 6.1 Simulator Testing (Every Phase)

- Full workflow walkthroughs in Garmin device simulator
- Memory usage profiling (Connect IQ has tight limits)
- Screen rendering on multiple device resolutions
- Edge cases: rapid button presses, back-button at every screen, app backgrounding
- Data persistence: kill and restart app, verify waypoints survive
- Battery simulation: long-duration activity recording

### 6.2 Field Testing (Phase 4+)

- Test with actual Garmin Alpha/Astro handheld and collars in field conditions
- Verify GPS accuracy for waypoints (compare to known coordinates)
- Test compass calibration and bearing accuracy
- Validate in various weather: cold (below freezing), wet, bright sunlight, dusk
- Test battery life during full-day hunt (8+ hour target)
- Verify ANT+ range and reliability at various distances from handheld
- Test with 1, 2, 3, and 4+ dogs on collars simultaneously

### 6.3 Edge Cases

- No GPS signal (dense tree cover)
- No ANT+ handheld connection / handheld powered off
- Low battery scenarios (< 10%)
- Maximum waypoint storage (stress test with 500+ waypoints)
- Screen timeout during critical operations (flush workflow)
- Rapid button presses (debounce validation)
- Compass near large metal objects (truck, gun)
- Activity pause and resume with active downed bird markers
- App crash recovery: verify no data loss

### 6.4 Success Metrics

| Metric | Target | Acceptable |
|--------|--------|------------|
| GPS waypoint accuracy | ±5 meters | ±10 meters |
| Compass bearing accuracy | ±3 degrees | ±5 degrees |
| Dog position update latency | < 1 second | < 2 seconds |
| Battery life (active use) | 10+ hours | 8+ hours |
| App launch time | < 2 seconds | < 3 seconds |
| Flush mark workflow time | < 8 seconds | < 10 seconds |
| Downed bird mark time | < 10 seconds | < 15 seconds |
| Zero data loss | 100% | 100% |

---

## 7. Known Limitations & Risks

### Technical Limitations

- Connect IQ has strict memory constraints (varies by device, typically 64–128KB for apps)
- ANT+ dog tracker protocol is not officially documented by Garmin — relies on community research and reverse engineering
- ANT+ apps require additional review by Garmin's ANT team for store submission
- Map rendering performance varies significantly by device — older devices may struggle
- Background processing is restricted; app may not update dog positions when not in foreground
- Compass accuracy degrades near metal objects (gun barrel, truck)
- System 8 security warnings for ANT sensors using non-native pairing flow

### User Considerations

- Hunters wear heavy gloves — all touch targets must be oversized
- Bright sunlight and rain make screens hard to read — high contrast is mandatory
- Quick access is critical — every extra tap is a missed opportunity in the field
- Dogs go on point suddenly — alerts must be immediate and unmissable
- Battery life is critical for all-day hunts in remote areas with no charging
- No cellular service in many hunting areas — all features must work fully offline

### Risk Matrix

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| ANT+ protocol undocumented | HIGH | Reference existing apps (ekutter), Garmin forums, thisisant.com. Build with mock data first. |
| Memory limits exceeded | MEDIUM | Profile memory early. Lazy-load screens. Cap stored waypoints. |
| Store rejection (ANT) | MEDIUM | Follow all ANT+ guidelines. Side-load for personal use as fallback. |
| Compass inaccuracy in field | MEDIUM | Prompt user to calibrate. Show confidence indicator. GPS fallback. |
| Battery drain too high | LOW | Configurable GPS polling. Aggressive screen sleep. Profile early. |

---

## 8. Future Enhancements (Post-V1)

- Integration with hunting log apps (iSportsman, HuntStand)
- Photo attachment to waypoints (via Garmin Connect Mobile companion)
- Weather data integration (barometric pressure from device sensor)
- Multi-user shared dog tracking (multiple watches, same handheld)
- Export to mapping software (OnX Hunt, HuntStand, Google Earth)
- Voice commands (if supported by future devices)
- Season-over-season statistics and analytics
- Public land boundary awareness
- Sunrise/sunset display and legal hunting hours countdown
- Wind direction indicator (useful for scent management)

---

## 9. Resources & References

### Garmin Developer Resources

- Connect IQ Documentation: https://developer.garmin.com/connect-iq/
- Connect IQ SDK Download: https://developer.garmin.com/connect-iq/sdk/
- Monkey C API Reference: https://developer.garmin.com/connect-iq/api-docs/
- Connect IQ Forums: https://forums.garmin.com/developer/connect-iq/
- System 8 Announcement: https://forums.garmin.com/developer/connect-iq/b/news-announcements

### ANT+ Resources

- ANT+ Developer Portal: https://www.thisisant.com/ (registration required)
- ekutter Dog Tracker (reference implementation): https://ekutter.github.io
- Garmin Forums ANT+ dog tracker discussion threads

### Existing Dog Tracker Apps (Study These)

- Dog Tracker by ekutter — most established, data field and app versions
- Dog Tracker Plus — Connect IQ store
- Garmin's built-in DogTrack widget on Fenix/Instinct series

---

## 10. Deliverables

- Connect IQ project source code (Monkey C)
- Build configuration for Fenix 8 Solar (primary) + secondary devices
- README with setup, build, and side-load instructions
- Unit tests for coordinate math and data persistence
- User guide (README_USER.md)
- API integration notes for ANT+ dog tracker protocol
- Known issues and limitations document (ISSUES.md)
- App icon (multiple sizes for Connect IQ store)
- Screenshots for app store listing
