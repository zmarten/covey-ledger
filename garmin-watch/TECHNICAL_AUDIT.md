# Upland Hunter — Technical Audit Report

**Date:** 2026-03-26
**Auditor:** Claude (Garmin Connect IQ Expert)
**App Version:** Build 2026-03-10, 176KB binary
**SDK:** Connect IQ SDK 8.4.1
**Primary Target:** fenix8solar51mm (454x454 AMOLED, API 5.0.1)

---

## Executive Summary

The app is architecturally sound with good code hygiene and extensive comments. All five phases compiled clean to zero warnings. The core flush-marking workflow is solid, the data model is correct, and the error handling philosophy (never crash in the field) is applied consistently. There are no showstopper bugs visible in static analysis.

That said, there are several issues that must be addressed before store submission, and others that matter significantly for CoveyTracker integration. This audit documents them by severity and category.

---

## 1. Code Quality Audit

### 1.1 Memory Management

**Overall: GOOD with specific risks at scale**

**Breadcrumb `slice()` leak (Medium Risk)**
File: `UplandHunterApp.mc`, line 216.
When the breadcrumb array is at capacity, the code calls:
```
_breadcrumbPositions = _breadcrumbPositions.slice(1, null) as Array;
```
`slice()` allocates a new array and abandons the old one. On the Fenix 8 Solar's managed runtime this will be collected, but this is called every 5 seconds when at capacity (after ~16 minutes of hunting). The old 200-element array is in limbo until the next GC cycle, temporarily doubling the breadcrumb memory (~10KB spike). A better pattern is a circular ring buffer using a write index — but that requires more code and the current approach is acceptable given the infrequent trigger. Low crash risk, worth noting.

**`getOrCreateDog()` linear scan (Low Risk)**
File: `DogTrackerSensor.mc`, line 406.
Every ANT+ message triggers a linear scan of the `_dogs` array to find or create a dog entry. With up to 20 dogs and messages arriving at ~8Hz, this is a tight loop. For 3 dogs it is negligible. For 20 dogs it is ~160 comparisons per second. This is acceptable on the Fenix 8 but would matter on a resource-constrained device. A `Dictionary` keyed by dog index would be O(1) and is worth using given the scan happens in an ANT+ callback.

**`WaypointManager.removeWaypointById()` allocates a new Array (Low Risk)**
File: `WaypointManager.mc`, line 158.
This function builds a new `newIds` array every time a waypoint is removed (which only happens when at the 500-waypoint cap). Not a meaningful concern at current scale.

**`loadAllWaypoints()` memory spike (Medium Risk)**
File: `WaypointManager.mc`, line 104.
The comment correctly flags this: loading all 500 waypoints at 100 bytes each is ~50KB. This is called from `getSessionWaypoints()`, which is called from:
- `ConfirmationView.saveWaypoint()` — every time a flush is recorded
- `SessionStatsView.onShow()`
- `PostHuntSummaryView.onShow()`
- `HuntMapView.refreshWaypoints()` every 10 seconds

The 10-second map refresh path is the concerning one. At 500 waypoints, you're doing a full load of all waypoints into a temporary array, filtering to session waypoints, and the full array is then garbage. On a long hunt (approaching 500 total waypoints across sessions) this could cause noticeable stutters or OOM pressure on the map screen. Consider adding a waypoint count check and warning if above 300.

**`PopChainHelper` timer leak on double-dismiss (Low Risk)**
File: `ConfirmationView.mc`, line 283.
If the user taps SELECT or BACK on the `ConfirmationView` while the auto-dismiss timer is still pending, `popToMainView()` is called twice. The second call creates a second `PopChainHelper` instance and assigns it to `_popHelper`, but the first `PopChainHelper`'s timer is still running and holds a `method(:popNext)` reference. This means an extra `popView()` call fires 50ms later on whatever screen the user landed on. This is the most likely runtime bug in the current codebase. Fix: cancel `_dismissTimer` before calling `popToMainView()`:
```
function popToMainView() as Void {
    if (_dismissTimer != null) {
        _dismissTimer.stop();
        _dismissTimer = null;
    }
    _popHelper = new PopChainHelper(_workflowDepth);
    _popHelper.startPopping();
}
```

**DogTrackerMock module-level arrays never cleared (Low Risk)**
File: `DogTrackerMock.mc`, lines 37-47.
`DogTrackerMock._dogs` and `DogTrackerMock._timerHelper` are module-level (effectively static) variables. After `stop()` is called, `_dogs` holds 3 DogData objects. This is only 3 small objects and the mock is not used in production, but if the mock is ever re-enabled as a fallback it should explicitly null out `_dogs` after stop.

### 1.2 Error Handling Completeness

**Overall: GOOD on critical paths, gaps on ANT+ and sensor paths**

**ANT+ message payload not validated for type (Medium Risk)**
File: `DogTrackerSensor.mc`, line 296.
`parseBroadcastData()` checks `payload.size() < 8`, which is correct. But it then casts bytes directly: `payload[0] as Number`, `payload[1] as Number`, etc. If the ANT+ handheld sends unexpected data types in the payload array (unlikely but possible with non-standard firmware), these casts could throw a `InvalidTypeException`. The parse functions should be wrapped in try/catch:
```
function parseBroadcastData(payload as Array) as Void {
    try {
        if (payload.size() < 8) { return; }
        // ... existing logic
    } catch (ex) {
        System.println("ANT+ parse error: " + ex.getErrorMessage());
    }
}
```

**`onMessage()` channel reopen after close has no guard (Medium Risk)**
File: `DogTrackerSensor.mc`, line 261.
When `MSG_CODE_EVENT_CHANNEL_CLOSED` fires, the code calls `_channel.open()`. But `_channel` could be `null` if `close()` was called intentionally (e.g., hunt ended, then this callback fires from the OS). The null check `if (_channel != null)` is present, so this path is safe. Good.

However, there is a subtle issue: if the channel is closed intentionally and the callback still fires, `_channel` is already `null` (set in `close()`), so the reopen is skipped. This is correct behavior. But `_connectionState` is set to `ANT_STATE_LOST` in the callback before the null check, even if we intentionally closed it. After `close()`, the state should stay `IDLE`. This is cosmetic but could cause the UI to briefly show "connection lost" when the user ends a hunt.

**`CoordinateMath.formatDistance()` does not null-check `unitSystem`**
File: `CoordinateMath.mc`, line 227.
```
var unitSystem = Application.Properties.getValue("unitSystem") as Number;
```
This is the one place in the codebase that directly casts the property value without null-checking first. Every other property access uses null-check patterns like `if (unit != null && unit == 1)`. If `unitSystem` is not set (first launch, or corrupt properties), this will throw a `NullReferenceException`. The `Constants.isMetric()` pattern should be used here instead.

**`ConfirmationView.onShow()` haptic check is inverted (Bug)**
File: `ConfirmationView.mc`, line 88.
```
if (hapticEnabled != false && Attention has :vibrate) {
```
`hapticEnabled` is a `Boolean` property. When it is `null` (not yet set), `hapticEnabled != false` evaluates to `true`, so haptic fires — which is the intended default behavior (opt-out). But the `Constants.isHighContrast()` pattern uses `if (hc != null && hc)` which is safer and explicit. The check in `MainView.triggerPointAlert()` uses `if (hapticEnabled != null && !hapticEnabled)` which correctly reads as "if explicitly disabled". The two files use different idioms for the same setting. Both work but one is more fragile. Standardize on the `MainView` pattern.

**`HuntSession.updatePosition()` called with null guards upstream but not itself null-safe**
File: `HuntSession.mc`, line 83.
The caller in `UplandHunterApp.onPosition()` checks `info.position != null` before calling `updatePosition()`. This is correct. No issue here.

### 1.3 Connect IQ API Best Practices

**`WatchUi.getCurrentView()[0]` pattern — acceptable but fragile**
Used throughout all delegates (SpeciesSelectDelegate, QuantityDelegate, etc.). This is the standard Connect IQ pattern for getting the current view from its delegate. The cast `as SpeciesSelectView` will throw if the view stack is in an unexpected state. This is acceptable given the deterministic navigation flow, but worth noting.

**`MapTrackView.clear()` usage is ambiguous (Medium Risk)**
File: `HuntMapView.mc`, line 237.
```
} else {
    clear();
}
```
`clear()` is inherited from `MapTrackView` and is documented to clear all map overlays. This is called when there are zero markers. But `MapTrackView.clear()` may also clear the polyline (breadcrumb trail) depending on the SDK implementation. The breadcrumb is added via `setPolyline()` in a separate call in the same update cycle, so the order matters: if `clear()` runs, then `updateBreadcrumb()` runs, the polyline should survive. The code calls `updateMarkers()` then `updateBreadcrumb()`, and `clear()` is inside `updateMarkers()`. This ordering is safe.

**Strings are hardcoded in views, not loaded from `strings.xml` (Low)**
`strings.xml` contains localized string resources for all labels. But the view files (`MainView.mc`, `SpeciesSelectView.mc`, etc.) use hardcoded string literals like `"UPLAND HUNTER"`, `"GPS Ready"`, `"SELECT SPECIES"`. The `@Strings.*` resources are defined but unused in code. For single-language English-only apps this is fine, but it means the string resource file is dead code. Either delete `strings.xml` or wire it up with `WatchUi.loadResource(Rez.Strings.AppName)`. This is a minor maintainability issue.

**`Sensor.enableSensorEvents(null)` in `onHide()` is correct**
File: `BearingCaptureView.mc`, line 191. This is the proper way to deregister the sensor callback. No issue.

**No `has` check on `Attention.vibrate` in `triggerPointAlert()`**
File: `MainView.mc`, line 289.
```
if (Attention has :vibrate) {
```
This `has` check is present and correct. The `ConfirmationView` also has this check. Good.

**`System.getTimer()` overflow in `DebounceHelper` (Very Low Risk)**
File: `DebounceHelper.mc`, line 57.
`System.getTimer()` returns milliseconds since app start as a `Number` (32-bit signed integer in Monkey C). At 2^31 ms = ~24.8 days of app uptime, it wraps to negative. `now - _lastEventTime < _debounceMs` would then compute a very large positive value, causing the debounce to accept every press for one cycle. In practice, no hunt lasts 24 days. Not a real concern.

### 1.4 Performance Concerns

**Map view allocates many `Position.Location` objects every 2 seconds (Medium)**
File: `HuntMapView.mc`, `updateMarkers()`.
Every 2-second update cycle creates:
- N `Position.Location` objects for waypoints (up to session count)
- M `Position.Location` objects for bird markers (up to 10)
- D `Position.Location` objects for dogs (up to 20)
- N + M + D `WatchUi.MapMarker` objects

On a long hunt with 50 waypoints and 3 dogs, that is 53+ object allocations every 2 seconds. This is the highest GC pressure point in the app. The `_cachedWaypoints` array helps (only reloaded every 10 seconds), but the marker objects are always recreated. The Garmin Map API requires this since `setMapMarker()` takes a fresh array each call. This is acceptable on the Fenix 8 (large memory) but could cause stutters on the Forerunner 965 (smaller GC heap). Monitor in field testing.

**`onUpdate()` in all views is clean**
No object allocations happen inside any `onUpdate()` method. String formatting (`format()`) creates temporary strings but these are short-lived. The 1-second timer pattern in `MainView` is correct and efficient.

**NavigationView updates at 500ms with GPS-based recalculation**
File: `NavigationView.mc`, line 70.
The 500ms timer calls `updateNavigation()` which calls `haversineDistance()` and `calculateBearing()` (trig operations). At 2 calls per second of floating-point trig, this is fine on a Fenix 8 ARM Cortex. No concern.

**ANT+ callback frequency**
The `MESSAGE_PERIOD = 4096` corresponds to roughly 8 messages per second from the handheld. Each message triggers `onMessage()` → `parseBroadcastData()` → `parseDogDataPage()` with a linear `_dogs` array scan. At 3 dogs and 8Hz this is 24 scans per second, each O(3). Negligible.

### 1.5 Settings/Properties Usage

**Overall: Correct with one null-cast bug (documented above in 1.2)**

All four properties (`unitSystem`, `gpsPollRate`, `hapticEnabled`, `highContrast`) are read consistently via the `Constants.*` helper functions which apply the correct null-check and default-value patterns. The settings XML is correctly formatted and the `@Properties.*` references are valid. Settings edited via Garmin Connect Mobile are picked up at the next `Properties.getValue()` call since values are read at render time, not cached.

One improvement: `gpsPollRate` is read on every GPS callback (via `Constants.getGpsPollInterval()` which calls `Properties.getValue()`). This means every GPS update (~1/sec) does a properties lookup. Caching this value in `UplandHunterApp` and only refreshing it in `onSettingsChanged()` would be slightly more efficient, but this is not a meaningful bottleneck in practice.

### 1.6 FIT File Recording Correctness

**Overall: Mostly correct with gaps in field richness**

The session correctly uses `ActivityRecording.createSession()` with `SPORT_HIKING` and `SUB_SPORT_GENERIC`. The activity name `"Upland Hunt"` will appear in Garmin Connect. The three custom FIT fields are:

| Field Name | Field ID | Data Type | Mesg Type |
|---|---|---|---|
| `total_flushes` | 0 | UINT16 | SESSION |
| `total_birds_down` | 1 | UINT16 | SESSION |
| `shots_taken` | 2 | UINT16 | SESSION |

**Critical Issue: FIT fields are session-level aggregates, not per-event records**
These three fields record totals at the session level (end of hunt). There are NO per-event FIT records for individual flushes. This means Garmin Connect will show the GPS track + three totals, but there is no timeline of when each flush occurred, no species breakdown, and no waypoint coordinates in the FIT file. The detailed waypoint data lives only in the Object Store (`Application.Storage`).

This is the single biggest limitation for CoveyTracker integration via FIT. See Section 5 (Data Portability) for the full analysis and recommendations.

**FIT field values are correct**
The update logic in `ConfirmationView.saveWaypoint()` correctly recalculates totals from `getSessionWaypoints()` after each save and calls `updateFitData()`. The `_fitShotsCount` counter correctly counts both HIT and MISSED results as shots taken (matching the stats display). Good.

**FIT `_huntStartTime` uses `System.getTimer()` not wall clock**
File: `UplandHunterApp.mc`, line 291.
`_huntStartTime = System.getTimer();` stores milliseconds since app start. `getHuntDuration()` computes `(System.getTimer() - _huntStartTime) / 1000`. This is correct for elapsed time display. The FIT session's own start/end timestamps are managed by the `ActivityRecording.Session` API automatically. No issue.

---

## 2. Store Submission Readiness

### 2.1 Manifest Review

**App ID: Needs Garmin registration**
```xml
id="a3421bee-d4b4-4c7e-9e5b-1a2b3c4d5e6f"
```
This appears to be a placeholder UUID. Before store submission, register the app at https://apps.garmin.com/developer to obtain a real app ID. Submitting with a placeholder UUID will be rejected.

**App Type: Correct**
`type="watch-app"` is correct for a full interactive application.

**Min API Level: Correct**
`minApiLevel="5.0.1"` is appropriate. This aligns with the SDK 8.4.1 requirement mentioned in BUILD_LOG.md and covers all listed target devices.

**Permissions: All Present and Required**
| Permission | Used For | Present |
|---|---|---|
| `Positioning` | GPS waypoints | Yes |
| `Sensor` | Compass in BearingCaptureView | Yes |
| `SensorHistory` | (Declared but not used in code) | Yes |
| `Ant` | Alpha/Astro handheld connection | Yes |
| `Fit` | ActivityRecording session | Yes |
| `FitContributor` | Custom FIT fields | Yes |
| `UserProfile` | (Declared but not used in code) | Yes |

**`SensorHistory` and `UserProfile` are declared but unused.** The store reviewer may ask about these. Either remove them (cleaner) or add a brief use. Unused permissions could trigger a review question.

**Device list assessment:**
The 10 devices listed are a reasonable starting set. However, notable omissions for the upland hunting market:
- `instinct2solar` — the Instinct line is extremely popular with hunters and outdoors users
- `instinct3solar` — newer Instinct
- `marq2` — premium market device
- `tactix8` — not yet in SDK 8.4.1 per BUILD_LOG (understandable)

The Instinct omission is significant for market reach. Instinct devices have ANT+ Generic Channel support and the screen resolution differences are manageable. Consider adding them.

**Missing store listing fields:**
The manifest does not include fields required for the store listing page:
- No `<iq:purchaseRequired>` element (should be `false` for free apps)
- No developer description or long description (handled in store portal, not manifest)

These are managed in the Garmin developer portal at submission time, not in the manifest itself. They are not missing from the manifest but need to be prepared separately.

### 2.2 Launcher Icon Assessment

Current state: 105-byte PNG, 40x40 pixels, plain orange square (confirmed by file size and BUILD_LOG note).

**Store requirements for launcher icons:**
- The Connect IQ store requires icons in multiple sizes for the app listing
- The manifest reference to `@Drawables.LauncherIcon` is a single bitmap
- In-watch display requires: 40x40px minimum (what's present)
- Store listing requires: 260x260px (for the listing page thumbnail), 512x512px (for featured placement)

**What needs to happen:**
1. Design a proper upland hunting icon (suggested: rooster pheasant silhouette or dog on point, in orange on dark background)
2. Replace `launcher_icon.png` with a proper 40x40px PNG for the watch display
3. Prepare 260x260 and 512x512 versions for the store listing portal
4. For devices with different DPI, add device-specific resource folders:
   ```
   resources-fenix8solar51mm/drawables/launcher_icon.png  (high DPI)
   resources/drawables/launcher_icon.png                  (standard)
   ```

The icon is the most visible blocker for a professional store listing.

---

## 3. FIT Data Export Assessment

### 3.1 What is in the FIT file after sync to Garmin Connect

When the hunt activity syncs to Garmin Connect, the FIT file contains:

**Session message fields:**
- `sport = SPORT_HIKING` (displayed as "Hiking" in Connect UI)
- `sub_sport = SUB_SPORT_GENERIC`
- `total_timer_time` — hunt duration in seconds (from ActivityRecording API)
- `total_elapsed_time` — same
- `start_time` — hunt start UTC timestamp
- Developer fields (visible under "Developer Data" in Connect):
  - `total_flushes` (uint16): total flush events
  - `total_birds_down` (uint16): total birds retrieved
  - `shots_taken` (uint16): number of shots fired

**Record messages (GPS track):**
- GPS coordinates every ~1 second (the actual rate depends on device GPS)
- `heart_rate` (if a heart rate sensor is active — will be 0 for no chest strap)
- Standard activity record fields

**What is NOT in the FIT file:**
- Individual flush events with timestamps
- Species per flush
- Quantity per flush
- Shot result per flush
- GPS coordinates per flush (as course points or events)
- Dog name at time of flush
- Any waypoint data at all

### 3.2 Programmatic access after sync

**FIT files are accessible after sync** via:
- Garmin Connect web API (requires OAuth, for approved partners)
- Direct FIT file download from Garmin Connect (authenticated user)
- Unofficial Garmin Connect API libraries (e.g., `garminconnect` Python library)

The three developer fields (`total_flushes`, `total_birds_down`, `shots_taken`) will appear in the FIT file's session message and can be parsed by any FIT SDK parser that supports developer fields. The `FitContributor` developer field format is standardized and parseable with:
- Official Garmin FIT SDK (Java/C++)
- `fit_tool` Python library
- `python-fitparse` with developer field support

**However**, the data is extremely limited for CoveyTracker integration. You get three integers at the end of the hunt. No timeline, no species, no coordinates.

### 3.3 Recommendations for richer FIT integration

To make the FIT file useful for ecosystem integration, add per-flush FIT records using `FitContributor.MESG_TYPE_EVENT` or `FitContributor.MESG_TYPE_RECORD` fields. This requires adding new FIT fields for flush-specific data and writing them at the time of each flush:

```monkey-c
// In UplandHunterApp, add these fields:
var _fitFlushSpecies as FitContributor.Field?;
var _fitFlushLat as FitContributor.Field?;
var _fitFlushLon as FitContributor.Field?;
var _fitFlushShot as FitContributor.Field?;

// Create with MESG_TYPE_RECORD (not SESSION):
_fitFlushSpecies = _session.createField(
    "flush_species", 3,
    FitContributor.DATA_TYPE_UINT8,
    {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "enum"}
);
```

Then write these at flush-record time in `ConfirmationView.saveWaypoint()`. The limitation is that RECORD-type fields are included in every record message (once per GPS update), so the "flush event" data would be interpolated across the track. A cleaner approach is to use MESG_TYPE_LAP to create a "lap" for each flush, which is non-standard but FIT-parseable.

The most practical solution for CoveyTracker integration is **not FIT** — it is Object Store export (see Section 5).

---

## 4. ANT+ Integration Review

### 4.1 Channel Configuration

The channel is configured as:
- Type: `CHANNEL_TYPE_RX_NOT_TX` (slave receive) — correct
- Network: `NETWORK_PLUS` (ANT+) — correct for Garmin Alpha/Astro
- Device type: `0` (wildcard) — correct for discovery
- Frequency: `57` (2457 MHz) — correct ANT+ standard frequency
- Period: `4096` — ~8 msg/sec, reasonable for tracking
- Search timeout: `12` low priority + `2` high priority = ~35 seconds total before timeout

The channel configuration is technically sound. The unknowns are entirely in the packet protocol, not the channel setup.

### 4.2 Packet Parsing Robustness

**The byte layout is entirely estimated.** The code is correct in structure but the specific byte positions, page IDs (1, 2, 3), and status byte values (0=moving, 1=stationary, etc.) are unverified. This is clearly documented in ISSUES.md and the source code itself.

Specific risks:
- **Page ID `1`** is the correct approach (ANT+ data pages use byte 0 as the page number). But the actual Alpha/Astro page numbering may differ.
- **Distance encoding** (bytes 2-3, little-endian, meters): the Alpha/Astro may use yards natively, or may use a different scale factor. If the unit is wrong, distances will display in yards but be numerically wrong.
- **Bearing encoding** (bytes 4-5, degrees * 10): the handheld may encode bearing differently (could be relative to handheld heading, not absolute north).
- **Status byte** (byte 6): the mapping `0=moving, 1=stationary, 2=on_point, 3=treed` is a guess. The actual status encoding from Garmin firmware is proprietary.

The `default: return Constants.DOG_STATUS_COMM_LOST` fallback in `mapStatusByte()` is a good safety net — unknown statuses show as "lost" rather than incorrect states.

### 4.3 Error Recovery

Auto-reconnect on both `EVENT_RX_SEARCH_TIMEOUT` and `EVENT_CHANNEL_CLOSED` is implemented. The reconnect logic calls `_channel.open()` which is correct — reopening a closed channel is the right approach.

**Risk: infinite reconnect loop.** If the channel repeatedly fails and closes immediately (hardware fault, no ANT channels available), the auto-reconnect loop will continuously open and close the channel. There is no backoff and no maximum retry count. This is low risk in practice (ANT channels are stable once opened) but should be addressed with a retry counter:
```
var _reconnectCount as Number = 0;
// In reconnect logic:
if (_reconnectCount < 5) {
    _channel.open();
    _reconnectCount++;
}
```

### 4.4 No Handheld Present Behavior

When no Alpha/Astro handheld is present:
1. Channel opens and enters `SEARCHING` state
2. After 30 seconds (search timeout), transitions to `LOST` and auto-reopens
3. This cycle repeats indefinitely while a hunt is active
4. `MainView` shows "No dogs connected" (since `ANT_STATE_LOST` != `ANT_STATE_CONNECTED`)

This is correct and acceptable behavior. The UI correctly degrades when no handheld is present. The hunt features (flush marking, bird locator, GPS tracking, stats) all work without the dog tracker.

**One issue:** The `_connectionState` in `ConfirmationView` shows the wrong state for a brief period when the search times out and before the auto-reconnect establishes. The UI shows "No dogs connected" rather than "Searching" because `ANT_STATE_LOST` is treated the same as `ANT_STATE_IDLE`. This is the current code in `MainView.drawDogList()`:
```
} else if (connState != Constants.ANT_STATE_CONNECTED || dogs.size() == 0) {
    // Shows "No dogs connected"
```
`ANT_STATE_LOST` falls through to this branch. Consider adding `ANT_STATE_LOST` to the "searching" display case to show "Reconnecting..." when reconnect attempts are ongoing.

### 4.5 DogTrackerPairingDelegate Stub

The `onScan()` implementation immediately calls `Sensor.notifyScanComplete()` without actually scanning. This means the native pairing UI will show an empty device list, which is confusing. The full implementation requires iterating over nearby devices — this is the documented limitation in ISSUES.md. For the first release, this is acceptable with a note in the app description that pairing is automatic (the channel uses wildcard discovery). The pairing delegate can be improved in a future update.

---

## 5. Data Portability Analysis

### 5.1 Data Persisted to Object Store (survives app restart)

The Object Store retains data across:
- App stop/restart
- Watch reboot
- Firmware updates

**Persisted data:**
- All waypoints (`wp_<timestamp>` keys)
- Waypoint ID index (`waypoint_ids`)
- Waypoint count (`waypoint_count`)

**Each waypoint contains:**
- `lat`, `lon` (Double): GPS coordinates of the flush
- `time` (Number): Unix timestamp
- `species` (Number): Species enum (0-10)
- `flushed` (Number): Count of birds flushed
- `down` (Number): Count of birds downed
- `shot` (Number): Shot result (0=hit, 1=missed, 2=no shot)
- `covey` (Number?): Covey size (nullable, quail/partridge only)
- `dogPt` (Boolean): Whether a dog was on point
- `dogNm` (String?): Dog name that was on point

**Not persisted (lost on session end):**
- Breadcrumb trail positions (`_breadcrumbPositions`) — in-memory array only
- Bird markers (downed bird locations) — in-memory, cleared on hunt end
- Dog tracker live data — in-memory only, comes from ANT+ live feed
- Hunt session distance and start time — in-memory, readable during session only
- `HuntSession` object state — not saved

### 5.2 Data Available for Export/Integration

**What's accessible for CoveyTracker:**
A web app could read data from three sources:

1. **Garmin Connect FIT file** — only 3 integers (totals). Very limited.

2. **Object Store data** — rich per-flush data. The Object Store is on-device only. There is no built-in sync to a web API. To extract this data:
   - Use `Toybox.Communications.transmit()` (Bluetooth to phone app) — requires a companion phone app
   - Use `Toybox.Communications.makeWebRequest()` — requires a backend API endpoint

3. **Connect IQ Companion App** — the cleanest integration path. A Connect IQ companion running in the Garmin Connect app on the phone can receive the Object Store data via `Toybox.Communications` and relay it to a backend. This requires building a companion component.

### 5.3 Recommended Export Architecture for CoveyTracker

The most practical path for data integration without writing a phone companion app:

**Option A: HTTP POST at hunt end (Recommended)**
At the moment `stopHuntActivity()` is called (hunt end), serialize all session waypoints to JSON and POST to a CoveyTracker API endpoint using `Communications.makeWebRequest()`. Requires phone to be connected via Bluetooth.

Data schema available for export:
```json
{
  "session": {
    "start_utc": 1743024000,
    "duration_seconds": 7200,
    "distance_meters": 6500
  },
  "flushes": [
    {
      "id": 1743024600,
      "lat": 43.6532,
      "lon": -116.6735,
      "utc": 1743024600,
      "species": 0,
      "flushed": 2,
      "down": 1,
      "shot": 0,
      "covey_size": null,
      "dog_on_point": true,
      "dog_name": "Rex"
    }
  ]
}
```

This gives CoveyTracker everything it needs: time, location, species, outcomes, and dog context. No FIT file parsing required.

**Option B: Garmin Connect Developer API (Future)**
With an approved developer account and OAuth integration, CoveyTracker could pull FIT files from Garmin Connect and parse the developer fields. This requires Garmin business partnership approval and is the highest-friction path.

**Option C: Companion App (Most Complete)**
Build a Monkey C companion component using `Communications.makeWebRequest()` triggered periodically during the hunt. This gives real-time updates to CoveyTracker. Higher development investment but enables live hunt tracking on a web dashboard.

---

## 6. Launcher Icon Assessment

**Current state:** 105-byte PNG at 40x40 pixels. A file this small is a solid-color image (approximately 3x compression), consistent with a plain orange square. This is confirmed by the BUILD_LOG note.

**What's needed for store submission:**

| Asset | Dimensions | Format | Usage |
|---|---|---|---|
| Watch display icon | 40x40px | PNG | `resources/drawables/launcher_icon.png` |
| Store thumbnail | 260x260px | PNG | Uploaded in developer portal |
| Store hero image | 512x512px | PNG | Uploaded in developer portal |
| Screenshot 1 | 454x454px | PNG | Main screen or map screen |
| Screenshot 2 | 454x454px | PNG | Flush workflow |
| Screenshot 3 | 454x454px | PNG | Stats or navigation screen |

**Icon design recommendation:**
Given the target audience (upland hunters), the icon should immediately communicate the app's purpose. Options:
- **Rooster pheasant silhouette** — universally recognizable in the upland hunting context
- **Dog on point** — instantly communicates the primary app feature (dog tracking)
- **Compass + bird feather** — combines navigation and hunting themes
- **Simple "UH" monogram on orange background** — simple, readable at 40px

At 40x40 pixels, complex detail is lost. The icon should be a single bold shape with high contrast against both dark and light system backgrounds. The `COLOR_PRIMARY = 0xEA580C` orange is a strong brand color that works at small sizes.

---

## 7. Prioritized Recommendations

### 7a. Required Before Store Submission

**P0 — Must fix (submission will be rejected without these):**

1. **Register the App ID.** The current `id="a3421bee-d4b4-4c7e-9e5b-1a2b3c4d5e6f"` is a placeholder UUID. Register at https://apps.garmin.com/developer and replace with the assigned ID.

2. **Replace the launcher icon.** The 40x40 orange square is unprofessional. Design and create a proper icon before submission. Also prepare 260x260 and 512x512 versions for the store portal.

3. **Fix the double-dismiss PopChainHelper bug.** Cancel `_dismissTimer` at the top of `popToMainView()` to prevent the orphaned timer from firing an extra `popView()` on the wrong screen. This is an active bug.

**P1 — Should fix before submission (affects review quality or user experience):**

4. **Remove unused permissions** (`SensorHistory`, `UserProfile`) or add minimal uses. The store review team will ask why these are declared.

5. **Fix `CoordinateMath.formatDistance()` null cast.** Change `Application.Properties.getValue("unitSystem") as Number` to use `Constants.isMetric()` to prevent a first-launch crash.

6. **Write at least three simulator screenshots.** Required for a professional store listing.

7. **Prepare store listing copy.** App description, category (Health & Fitness or Outdoors), keywords. The app name "Upland Hunter" is clear and searchable.

### 7b. Required Before CoveyTracker Ecosystem Integration

**P1 — Foundational for integration:**

8. **Add `Communications.makeWebRequest()` call at hunt end.** Serialize all session waypoints to JSON and POST to a CoveyTracker API endpoint. This is the highest-ROI single change for ecosystem integration. Add permission check:
   ```xml
   <iq:uses-permission id="Communications"/>
   ```
   Add to `manifest.xml` and implement in `stopHuntActivity()`.

9. **Add per-flush FIT records.** Create FIT record-type fields for `flush_species`, `flush_lat`, `flush_lon` so the FIT file contains individual flush events. This enriches the Garmin Connect activity view and provides a FIT-based fallback for data access.

10. **Write unit tests** for `CoordinateMath` (haversine, bearing, destination point). These are the highest-value tests — a sign error in the bearing formula could send hunters in the wrong direction. Files were specified in the project structure but not implemented.

**P2 — Important for long-term integration:**

11. **Implement MRU species sorting** in `SpeciesSelectView`. This is already tracked in ISSUES.md and directly improves data quality for CoveyTracker by reducing species mis-selections from a fatigued hunter.

12. **Add session ID to Object Store.** Currently there is no persistent session identifier. CoveyTracker integration needs a way to associate waypoints with a specific hunt outing. Store a `session_id` (e.g., the hunt start timestamp as a string) alongside waypoints so imported data can be grouped.

13. **Consider clearing waypoints after successful export.** The Object Store cap is 500 waypoints across all sessions. On a prolific hunting season, this fills up. After successful CoveyTracker sync, the app should offer to clear exported waypoints (with confirmation).

### 7c. Long-term Maintainability

**P2 — Improves future development:**

14. **Wire `strings.xml` or delete it.** The resource file is maintained separately from the code but not used. Either use `WatchUi.loadResource(Rez.Strings.*)` in views (enabling future localization) or remove the file and add a comment that string hardcoding is intentional.

15. **Implement `QuantityView` covey size input.** Currently the covey size field exists in the data model and UI display but there is no input method to set it. This is tracked in ISSUES.md. The covey size is a key data point for quail and partridge hunters.

16. **Add stale data detection for dog entries.** The `DogData.lastUpdateTime` field exists but is never checked. Dogs that haven't been heard from in >30 seconds should be flagged as `COMM_LOST` automatically, rather than showing the last known distance. Add a staleness check in `drawDogList()`.

17. **Add `ANT_STATE_LOST` visual distinction.** Show "Reconnecting..." instead of "No dogs connected" when the connection was established and then lost. The current code conflates initial "never connected" with "was connected, now lost."

18. **Address the `getBgColor()` and `getTextColor()` property reads per-frame.** Each view calls `Constants.getBgColor()` which calls `Properties.getValue()` every `onUpdate()`. Cache this value at the app level and expose it as a field, refreshing only in `onSettingsChanged()`.

---

## Summary Table

| Finding | Severity | Category | Fix Required For |
|---|---|---|---|
| App ID is placeholder UUID | Critical | Store | Store submission |
| Launcher icon is orange square | Critical | Store | Store submission |
| Double-dismiss PopChainHelper bug | High | Code | Store submission |
| Unused permissions (SensorHistory, UserProfile) | Medium | Store | Store submission |
| `formatDistance()` null cast bug | Medium | Code | Store submission |
| No per-flush FIT records | High | FIT/Ecosystem | CoveyTracker |
| No `Communications` permission or endpoint | High | Ecosystem | CoveyTracker |
| ANT+ protocol unverified with real hardware | High | ANT+ | Field testing |
| SensorDelegate pairing stub | Medium | ANT+ | System 8 UX |
| Infinite ANT reconnect loop (no backoff) | Low | ANT+ | Polish |
| No session ID in Object Store | Medium | Ecosystem | CoveyTracker |
| Unit tests not written | Medium | Quality | Long-term |
| Strings.xml unused/dead code | Low | Maintainability | Long-term |
| QuantityView covey size has no input | Low | Features | Long-term |
| Stale dog data not auto-cleared | Low | Features | Long-term |
| Breadcrumb trail uses slice() allocation | Low | Memory | Low priority |
| `getBgColor()` called per-frame | Low | Performance | Low priority |
| MRU species sort not implemented | Low | Features | Long-term |

---

*Audit completed by reading all 28 source files, 5 resource files, manifest.xml, monkey.jungle, CLAUDE.md, ISSUES.md, and BUILD_LOG.md.*
