# Upland Hunting Ecosystem -- Product Strategy

**Author:** Zach Martens (Product Manager)
**Date:** 2026-03-26
**Status:** Draft
**Version:** 1.0

---

## Table of Contents

1. [Ecosystem Vision](#1-ecosystem-vision)
2. [User Journey Map](#2-user-journey-map)
3. [Data Contract](#3-data-contract)
4. [Integration Options Analysis](#4-integration-options-analysis)
5. [Feature Gap Analysis](#5-feature-gap-analysis)
6. [Go-to-Market Readiness](#6-go-to-market-readiness)
7. [Phased Roadmap](#7-phased-roadmap)

---

## 1. Ecosystem Vision

### The Problem Today

Upland bird hunters operate in a fragmented tool landscape. In-field data capture (flushes, harvest, dog performance, GPS tracks) lives on a Garmin watch and syncs to Garmin Connect, where it sits as an undifferentiated "Hiking" activity with a handful of custom developer fields. Compliance tracking -- daily limits, possession limits, freezer inventory -- lives in a separate web app that the hunter populates manually after each hunt.

The manual bridge between "what happened in the field" and "what's my legal standing" is the weakest link. It introduces:

- **Data entry friction:** The hunter must re-enter species, quantities, and locations by hand after a long day afield. Tired hunters skip entries or get them wrong.
- **Compliance risk:** A missed entry or transposed number can push a hunter over a possession limit without realizing it. The entire value proposition of Covey Ledger depends on its ledger being accurate. Manual entry undermines that.
- **Lost analytical value:** Dog performance data, GPS tracks, flush locations, and success rates captured by the watch never flow into the long-term harvest record. Season-over-season analysis is impossible without manual collation.

### The Combined Value Proposition

**UplandHunter + Covey Ledger together create a closed-loop hunting platform where in-field events automatically feed compliance tracking and season analytics.**

| Capability | UplandHunter Standalone | Covey Ledger Standalone | Ecosystem Combined |
|---|---|---|---|
| Flush/harvest capture | Watch-only, FIT file with 3 summary fields | Manual web entry | Watch captures in real time; web receives structured data automatically |
| Compliance checking | None | Full engine (daily + possession limits) | Pre-hunt: watch shows remaining daily limit. Post-hunt: harvest data auto-populates compliance engine |
| Dog performance | On-screen only, session-scoped | None | Dog data preserved in hunt record; season-level performance analytics |
| Freezer inventory | None | Full tracking | Harvest entries from watch flow into possession math automatically |
| Season analytics | None | Basic history view | Combined GPS, flush, harvest, dog, and compliance data in one timeline |
| Location intelligence | GPS waypoints on map | State selector (no geo) | GPS coordinates auto-resolve to state; location-based regulation lookup |

### Vision Statement

> One platform, two surfaces. The watch captures the hunt in real time. The web app turns that data into compliance, analytics, and season intelligence. The hunter never manually enters a harvest that their watch already recorded.

### Strategic Principles

1. **Watch-first capture, web-first analysis.** The watch is optimized for fast, glove-friendly data entry in the field. The web app is optimized for viewing, adjusting, and analyzing that data later.
2. **Compliance is non-negotiable.** Every integration path must preserve Covey Ledger's server-side compliance enforcement. Watch data creates *draft* harvest entries that the compliance engine validates before they become permanent.
3. **Offline is the default.** Hunters operate without cell service. The watch must capture everything locally. Sync happens later, when the hunter has connectivity.
4. **Data fidelity over convenience.** It is better to require a 30-second review step on the web than to silently create an incorrect compliance record.
5. **Solo-dev pragmatism.** Every architectural choice must be buildable and maintainable by one developer. Eliminate complexity that does not directly serve users.

---

## 2. User Journey Map

### End-to-End Flow

```
PRE-HUNT                IN-FIELD                    POST-HUNT              SEASON
  |                        |                           |                     |
  v                        v                           v                     v
[Covey Ledger]        [UplandHunter Watch]        [Covey Ledger]        [Covey Ledger]
  |                        |                           |                     |
  | Check daily       | Start Hunt                | Sync FIT file      | Season History
  | limits remaining  | Mark Flushes              | Review draft        | Dog performance
  | Check possession  | Track dogs                |   harvest entries   | Species trends
  | Review regs       | Locate downed birds       | Confirm/edit        | Location heatmap
  | Set active state  | View session stats        | Compliance check    | Success rates
  |                   | End Hunt                  | End-of-day split    |
  |                   |                           | Update freezer      |
  |                   |                           |                     |
  +--------[1]--------+--------[2]---------+------+--------[3]----------+
           ^                    ^                           ^
     HANDOFF POINT 1     HANDOFF POINT 2            HANDOFF POINT 3
     "What can I           "Hunt data               "Draft entries
      still harvest?"       leaves the watch"         become records"
```

### Handoff Point 1: Pre-Hunt Preparation (Covey Ledger to Hunter)

**Current state:** The hunter opens Covey Ledger on their phone, checks their remaining daily and possession limits for the state they are hunting in, and mentally notes the numbers.

**Ecosystem state:** Same flow, but with an optional enhancement: the watch could display remaining daily limits for the active state as a pre-hunt reference screen. This requires the watch to receive limit data from Covey Ledger (see Data Contract, Section 3.2).

**Data flow:** Covey Ledger --> (phone/BLE) --> Watch settings or glanceable screen
**Data needed:** State name, species list, daily limit remaining per species
**Priority:** P2 (nice-to-have). The mental model of "check your phone before you leave the truck" is already natural. Watch-side limits add convenience but are not required for the ecosystem to function.

### Handoff Point 2: Hunt Data Leaves the Watch

**Current state:** The hunt ends. The watch saves a FIT file to Garmin Connect with 3 custom fields (total_flushes, total_birds_down, shots_taken). Individual waypoint data (species, quantity, GPS, shot result per flush) is stored only in the watch's Object Store and is not exported.

**Ecosystem state:** The FIT file or a companion data payload includes per-flush structured data that can be parsed by Covey Ledger. Each flush event maps to a potential harvest_entry in the compliance engine.

**This is the critical integration point.** The entire ecosystem value depends on getting structured, per-flush data from the watch to Covey Ledger with minimal hunter effort.

**Data flow:** Watch --> FIT file / companion payload --> Garmin Connect / phone --> Covey Ledger
**Data needed:** See Data Contract, Section 3.1
**Priority:** P0 (must-have for any integration)

### Handoff Point 3: Draft Entries Become Compliance Records

**Current state:** Does not exist. The hunter manually creates harvest entries in Covey Ledger.

**Ecosystem state:** Watch-originated data arrives in Covey Ledger as *draft harvest entries*. The hunter reviews them on the web app (or phone), confirms species/quantities (correcting any errors), and the compliance engine validates before saving. This preserves the compliance guarantee while eliminating manual data entry.

**Why drafts, not auto-confirmed entries:** The watch captures flush data, not harvest data. A flush of 3 pheasants where the hunter downed 2 means 2 birds harvested, but only if the hunter retrieved both. The bird locator helps, but the definitive count happens when the hunter is back at the truck. Compliance records must reflect actual possession, not field estimates.

**Data flow:** Covey Ledger import queue --> hunter review screen --> compliance engine --> harvest_entries table
**Priority:** P0 (must-have for any integration)

---

## 3. Data Contract

### 3.1 Watch to Web: Hunt Session Export

This is the primary data payload. Every hunt session on the watch should produce a structured export that Covey Ledger can ingest.

#### 3.1.1 Session Summary

```json
{
  "session": {
    "source": "upland_hunter_watch",
    "source_version": "1.0.0",
    "device": "fenix8solar51mm",
    "session_id": "2026-11-15T08:23:41Z_a3421bee",
    "start_time": "2026-11-15T08:23:41Z",
    "end_time": "2026-11-15T14:45:12Z",
    "duration_seconds": 22891,
    "distance_meters": 18432.5,
    "gps_track_available": true,
    "total_flushes": 14,
    "total_shots": 9,
    "total_birds_down": 6,
    "success_rate": 0.667
  }
}
```

#### 3.1.2 Flush Events (Per-Waypoint Data)

Each flush event from the watch maps to a potential harvest entry in Covey Ledger.

```json
{
  "flushes": [
    {
      "flush_id": 1731659021,
      "timestamp": "2026-11-15T09:03:41Z",
      "latitude": 39.7392,
      "longitude": -104.9903,
      "species_code": 0,
      "species_name": "Pheasant",
      "quantity_flushed": 2,
      "birds_down": 1,
      "shot_result": "hit",
      "covey_size": null,
      "dog_on_point": true,
      "dog_name": "Rex"
    },
    {
      "flush_id": 1731662441,
      "timestamp": "2026-11-15T10:00:41Z",
      "latitude": 39.7401,
      "longitude": -104.9887,
      "species_code": 1,
      "species_name": "Quail",
      "quantity_flushed": 12,
      "birds_down": 3,
      "shot_result": "hit",
      "covey_size": 16,
      "dog_on_point": true,
      "dog_name": "Belle"
    }
  ]
}
```

#### 3.1.3 Dog Performance Summary

```json
{
  "dogs": [
    {
      "dog_name": "Rex",
      "total_time_tracked_seconds": 22000,
      "points": 4,
      "flushes_from_points": 3,
      "birds_from_points": 2,
      "average_distance_yards": 85,
      "max_distance_yards": 340,
      "comm_lost_events": 1,
      "gps_lost_events": 0
    },
    {
      "dog_name": "Belle",
      "total_time_tracked_seconds": 22000,
      "points": 6,
      "flushes_from_points": 5,
      "birds_from_points": 4,
      "average_distance_yards": 120,
      "max_distance_yards": 510,
      "comm_lost_events": 0,
      "gps_lost_events": 2
    }
  ]
}
```

#### 3.1.4 Species Code Mapping

The watch uses integer enum codes. Covey Ledger uses UUID-referenced species records. A mapping table is required.

| Watch Code | Watch Name | Covey Ledger Species Name | Notes |
|---|---|---|---|
| 0 | Pheasant | Pheasant | Direct match |
| 1 | Quail | Quail | CL may need subspecies (Bobwhite, Gambel, Scaled) |
| 2 | Chukar | Chukar | Direct match |
| 3 | Grouse (Ruffed) | Grouse (Ruffed) | CL tracks as separate species |
| 4 | Grouse (Sage) | Grouse (Sage) | CL tracks as separate species |
| 5 | Grouse (Sharp-tail) | Grouse (Sharp-tailed) | Direct match |
| 6 | Woodcock | Woodcock | Direct match |
| 7 | Prairie Chicken | Prairie Chicken | Direct match |
| 8 | Partridge | Partridge (Hungarian) | Name normalization needed |
| 9 | Dove | Dove | Direct match |
| 10 | Other | -- | Requires manual species assignment on import |

**Key decision:** Species code 10 ("Other") cannot auto-map. The import flow must prompt the hunter to assign a species. Species code 1 ("Quail") may need subspecies disambiguation in states where different quail species have different limits.

### 3.2 Web to Watch: Regulation Context (Future, P2)

If the watch eventually displays remaining limits, Covey Ledger would need to push a compact regulation summary.

```json
{
  "active_state": "Kansas",
  "state_abbreviation": "KS",
  "date": "2026-11-15",
  "limits": [
    {
      "species_code": 0,
      "species_name": "Pheasant",
      "daily_limit": 4,
      "daily_remaining": 3,
      "possession_remaining": 12
    },
    {
      "species_code": 1,
      "species_name": "Quail",
      "daily_limit": 8,
      "daily_remaining": 8,
      "possession_remaining": 24
    }
  ]
}
```

**Constraints:**
- Watch has limited memory (64-128KB app RAM). This payload must be tiny.
- Watch has no persistent internet. Data would need to be pushed via Garmin Connect Mobile (phone) before the hunt starts.
- This is a convenience feature, not a compliance feature. The web app remains the authoritative source.

### 3.3 Mapping Watch Data to Covey Ledger Tables

#### Flush Event to harvest_entries

| Watch Field | Covey Ledger Field | Transformation |
|---|---|---|
| `species_code` | `species_id` | Lookup via mapping table; "Other" requires manual assignment |
| `birds_down` | `quantity` | Direct mapping. Only flushes with `birds_down > 0` create entries |
| `latitude` + `longitude` | `state_id` | Reverse geocode GPS coordinates to determine state. Fallback: hunter selects state manually |
| `timestamp` | `date` | Extract date portion (YYYY-MM-DD) from ISO timestamp |
| `flush_id` | (new field) `source_flush_id` | Deduplication key to prevent double-import |
| -- | `notes` | Auto-generated: "Via UplandHunter watch. Flush at [lat, lon]. Dog: [name]." |
| -- | `user_id` | From authenticated Covey Ledger session |

#### Key Transformation Rules

1. **Only flushes with `birds_down > 0` generate harvest entries.** A flush with `shot_result = "missed"` or `shot_result = "no_shot"` or `birds_down = 0` is recorded for analytics but does not create a compliance record.
2. **State determination from GPS.** The latitude/longitude from the flush can be reverse-geocoded to determine which state the harvest occurred in. This eliminates the need for the hunter to manually select a state. A simple bounding-box or point-in-polygon check against state boundaries is sufficient. Fallback: prompt the hunter to confirm or select the state during import review.
3. **Date extraction.** The timestamp from the watch is in UTC. Convert to the hunter's local timezone before extracting the date, because a hunt that ends at 11pm Mountain Time should not be recorded as the next day's harvest.
4. **Deduplication.** The `flush_id` (Unix timestamp of the flush) serves as a natural deduplication key. If a flush with the same `source_flush_id` already exists in Covey Ledger, skip it. This allows safe re-import.

#### Session Summary to Analytics (New Table)

The session summary data (duration, distance, total stats, dog performance) does not map to existing Covey Ledger tables. It requires a new `hunt_sessions` table.

```sql
CREATE TABLE hunt_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  source TEXT NOT NULL DEFAULT 'upland_hunter_watch',
  source_session_id TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  duration_seconds INTEGER NOT NULL,
  distance_meters NUMERIC(10,2),
  state_id UUID REFERENCES states,
  total_flushes INTEGER DEFAULT 0,
  total_shots INTEGER DEFAULT 0,
  total_birds_down INTEGER DEFAULT 0,
  success_rate NUMERIC(4,3),
  dog_data JSONB,
  gps_track JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

This table is for analytics only. It does not participate in compliance calculations. The `harvest_entries` table remains the sole input to the compliance engine.

---

## 4. Integration Options Analysis

Four paths exist for moving data from the watch to Covey Ledger. They are evaluated on five dimensions relevant to a solo developer building for personal use with eventual public release.

### Option A: Garmin Connect Developer Program (Activity API + Webhooks)

**How it works:** Register as a Garmin Connect developer. Implement OAuth so the hunter authorizes Covey Ledger to access their Garmin Connect data. When the hunter syncs their watch to Garmin Connect (via phone), Garmin pushes activity data to a webhook endpoint on Covey Ledger's backend. The webhook receives the FIT file, parses it for custom developer fields and track data, and creates draft harvest entries.

**Architecture:**
```
Watch --> (USB/BLE) --> Garmin Connect Mobile --> Garmin Connect Cloud
    --> (webhook push) --> Covey Ledger Supabase Edge Function
    --> Parse FIT --> Create draft harvest entries
```

| Dimension | Rating | Notes |
|---|---|---|
| Complexity | HIGH | OAuth flow, webhook endpoint, FIT file parsing, Garmin developer program approval (takes days-weeks). Must maintain a server endpoint that Garmin can reach. |
| Reliability | HIGH | Garmin's infrastructure is robust. Push model means data arrives automatically after sync. |
| User friction | LOW | Hunter syncs watch to phone (already a habit). Data appears in Covey Ledger automatically. |
| Developer effort | HIGH | FIT SDK parsing (binary format), OAuth implementation, webhook handler, developer program application. Estimated 3-4 weeks for a solo dev. |
| Data richness | MEDIUM | FIT custom fields are session-level only (3 summary fields currently). Per-flush waypoint data requires using FIT lap markers or course points -- non-trivial FIT SDK work. Standard GPS track is available. |

**Critical limitation:** The current UplandHunter app writes only 3 session-level FIT custom fields (total_flushes, total_birds_down, shots_taken). Per-flush data (species, quantity, GPS per event) is stored in the watch's Object Store, not in the FIT file. To use this path, the watch app would need to be modified to write per-flush data into the FIT file as lap markers, event records, or additional developer fields. This is doable but requires careful FIT SDK work and adds complexity to the watch app.

**Verdict:** Best long-term solution for a public product. Too heavy for an MVP. The Garmin developer program approval process and FIT parsing complexity make this a Phase 3+ investment.

### Option B: FIT File Manual Export + Web Upload

**How it works:** The hunter exports the FIT file from Garmin Connect (or directly from the watch via USB). They upload it to Covey Ledger's web interface. Covey Ledger parses the FIT file in the browser (client-side) or on the server and creates draft harvest entries.

**Architecture:**
```
Watch --> (USB) --> FIT file on computer
    --> Manual upload to Covey Ledger web UI
    --> Parse FIT (client-side JS or server-side)
    --> Create draft harvest entries
```

| Dimension | Rating | Notes |
|---|---|---|
| Complexity | MEDIUM | FIT parsing is the main challenge. The fitdecoder npm library or fit-file-parser can handle it in JavaScript. No OAuth, no webhooks. |
| Reliability | HIGH | File is a local artifact. No network dependencies during the hunt. |
| User friction | HIGH | Manual export + upload is clunky. Hunters will skip it when tired. |
| Developer effort | MEDIUM | FIT parser integration, upload UI, mapping logic. Estimated 1-2 weeks. |
| Data richness | MEDIUM | Same FIT limitation as Option A -- per-flush data requires FIT schema changes on the watch. |

**Critical limitation:** Same FIT data richness problem as Option A. Also, the manual upload step is a significant UX burden that will kill adoption over a season.

**Verdict:** Viable as a fallback or debugging tool. Not a primary integration path due to user friction.

### Option C: Connect IQ Communications Module (Watch to Phone to Web)

**How it works:** The watch app uses the Connect IQ `Communications.makeWebRequest()` API to send data directly to Covey Ledger's API endpoint, proxied through the paired phone's internet connection via Garmin Connect Mobile. At the end of a hunt, the watch serializes its flush data as JSON and POSTs it to a Supabase Edge Function.

**Architecture:**
```
Watch --> (BLE) --> Garmin Connect Mobile (phone)
    --> (HTTPS via phone) --> Covey Ledger Supabase Edge Function
    --> Validate + create draft harvest entries
```

| Dimension | Rating | Notes |
|---|---|---|
| Complexity | MEDIUM | The Communications module is well-documented. makeWebRequest() supports JSON payloads. Authentication requires a device token or pre-shared key since the watch cannot do OAuth. |
| Reliability | MEDIUM | Requires phone to be paired and have internet connectivity at the time of sync. If the hunter is in a dead zone at the truck, sync fails (must retry later). Connect IQ has a 16KB response limit, but request payloads are less constrained. |
| User friction | LOW | Sync happens from the watch at end of hunt (one button). If phone has service, data flows immediately. If not, queued for retry. |
| Developer effort | MEDIUM | Watch-side: serialize flush data to JSON, call makeWebRequest(). Web-side: Supabase Edge Function to receive and validate. Auth via pre-shared API key or device-specific token. Estimated 2-3 weeks. |
| Data richness | HIGH | We control the payload format entirely. Full per-flush data, dog performance, GPS track -- everything the watch knows can be sent. |

**Critical advantage:** This is the only option that sends per-flush structured data without modifying the FIT file schema. The watch already has all flush data in its Object Store. Serializing it to JSON and sending via makeWebRequest() is straightforward.

**Critical constraint:** makeWebRequest() requires the phone to be paired and connected. Hunters often lack cell service at the trailhead. The watch app must handle the case where the request fails and queue it for retry. Connect IQ supports background requests but with limitations.

**Verdict:** Best balance of effort, data richness, and user experience for a solo dev MVP. This is the recommended primary integration path.

### Option D: Companion Phone App (Connect IQ Mobile SDK)

**How it works:** Build a native Android/iOS companion app using the Connect IQ Mobile SDK. The companion app receives data from the watch via BLE, stores it locally, and syncs to Covey Ledger when internet is available. Alternatively, the companion app IS Covey Ledger's mobile version (a React Native or PWA wrapper).

**Architecture:**
```
Watch --> (BLE via CIQ Mobile SDK) --> Companion App (phone)
    --> Local storage on phone
    --> (HTTPS when available) --> Covey Ledger Supabase
```

| Dimension | Rating | Notes |
|---|---|---|
| Complexity | VERY HIGH | Building and maintaining a native companion app for Android (and ideally iOS) is a massive scope expansion. Requires Connect IQ Mobile SDK integration, BLE communication protocol, local database, sync engine. |
| Reliability | HIGH | BLE transfer is reliable at close range. Local phone storage handles offline. Sync when internet available. |
| User friction | LOW | Data transfers automatically when phone is near watch. Review happens in the companion app. |
| Developer effort | VERY HIGH | Native mobile app development for at least one platform. Connect IQ Mobile SDK has learning curve. Estimated 6-10 weeks for Android alone. |
| Data richness | HIGH | Full control over payload, same as Option C. |

**Verdict:** Overkill for a solo dev. If Covey Ledger ever becomes a mobile app (React Native), this becomes more interesting. Not viable for the current web-only architecture.

### Recommendation

**Phase 1 (MVP): Option C -- Connect IQ Communications Module.**

Rationale: It delivers the highest data richness with moderate effort, and it is the only option that avoids the FIT file per-flush data problem entirely. The watch already stores all the data we need in its Object Store. We serialize it, POST it, done.

**Phase 2 (Enhancement): Option B -- FIT Manual Upload as fallback.**

For hunters who use UplandHunter but do not use Covey Ledger's account system, or for debugging, a "upload your FIT file" feature in Covey Ledger provides a no-account-required import path.

**Phase 3 (Scale): Option A -- Garmin Connect Developer Program.**

If the product gains traction beyond personal use, the webhook-based flow eliminates the phone-connectivity dependency and makes the integration truly seamless.

---

## 5. Feature Gap Analysis

### 5.1 UplandHunter (Watch App) Gaps

#### P0 -- Must-Have for Integration

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Data export via Communications API** | Add `Communications.makeWebRequest()` call at end of hunt to POST flush data as JSON to Covey Ledger's API endpoint. | M (1-2 weeks) | Core integration feature. Must handle offline gracefully (queue + retry). |
| **Flush data serialization** | Serialize all waypoints from WaypointManager into JSON payload matching the Data Contract schema (Section 3.1). | S (2-3 days) | Monkey C has `Communications.makeWebRequest()` which accepts Dictionary payloads that convert to JSON. |
| **API key storage** | Store a Covey Ledger API key or device token in watch settings (via Garmin Connect Mobile settings UI). | S (1 day) | Add a new string setting in `settings.xml` and `properties.xml`. |
| **Sync status indicator** | Show sync state on main view or post-hunt summary: "Synced" / "Pending" / "Failed". | S (1-2 days) | Hunter needs to know if their data made it to Covey Ledger. |
| **Session data aggregation** | Aggregate dog performance stats (points, flushes-from-points, average distance) during the session for the export payload. | M (3-5 days) | Dog data is currently real-time display only. Need to accumulate session-level stats. |

#### P1 -- Should-Have for v1

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Per-flush FIT data** | Write individual flush events as FIT lap records or developer fields so data is available in Garmin Connect even without Covey Ledger sync. | M (1-2 weeks) | Requires FIT SDK research. Enables Option A/B integration paths in the future. |
| **MRU species sorting** | Track species usage frequency and sort the species list by most-recently-used. | S (2-3 days) | Listed in ISSUES.md as known gap. Speeds up flush workflow. |
| **Covey size selector fix** | Fix the covey size input on QuantityView -- UI shows covey size but has no input method to change it. | S (1-2 days) | Listed in ISSUES.md as known gap. |
| **Retry queue for failed syncs** | If makeWebRequest() fails (no internet), queue the payload and retry on next app launch or when connectivity is detected. | M (3-5 days) | Object Store can persist the pending payload. |
| **Proper launcher icon** | Replace the 40x40 orange placeholder with a proper hunting-themed icon at all required sizes. | S (1-2 days) | Required for store submission. Blocks go-to-market. |

#### P2 -- Nice-to-Have Future

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Receive daily limits from Covey Ledger** | Display remaining daily limits per species on a pre-hunt screen. Data pushed via phone settings or makeWebRequest response. | M (1-2 weeks) | Cool feature, low urgency. Mental check on phone works fine. |
| **Unit tests** | Write CoordinateMathTest.mc, WaypointManagerTest.mc, FlushWorkflowTest.mc. | M (3-5 days) | Listed in ISSUES.md as technical debt. Important for code confidence. |
| **Photo waypoint attachment** | Capture photo via Garmin Connect Mobile companion and link to a flush waypoint. | L (2-3 weeks) | Requires companion app coordination. |
| **Wind direction indicator** | Display wind direction from barometric sensor for scent management. | S (2-3 days) | Useful field feature, no integration dependency. |

### 5.2 Covey Ledger (Web App) Gaps

#### P0 -- Must-Have for Integration

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Import API endpoint** | Supabase Edge Function that receives the JSON payload from the watch (Section 3.1), validates the API key, and creates draft harvest entries in a new `import_queue` table. | M (1-2 weeks) | The heart of the integration. Must validate payload schema, deduplicate by flush_id, and NOT auto-commit to harvest_entries (drafts first). |
| **Draft harvest review UI** | New page in Covey Ledger where the hunter reviews imported flush data, confirms/edits species and quantities, selects state (or confirms auto-detected state), and submits to the compliance engine. | L (2-3 weeks) | Critical UX. Must show GPS location on a map, pre-fill species from watch data, and let the hunter adjust. |
| **Species mapping table** | Persistent mapping between UplandHunter species codes (integers 0-10) and Covey Ledger species records (UUIDs). Configurable in settings for edge cases (e.g., "Quail" on watch maps to "Bobwhite Quail" in Kansas). | S (2-3 days) | Seeded with defaults. User-editable for state-specific subspecies. |
| **hunt_sessions table** | New database table for session metadata (duration, distance, dog performance, total stats). Linked to harvest entries for analytics. | S (1-2 days) | Schema in Section 3.3. |
| **GPS-to-state resolution** | Given a lat/lon pair, determine which US state it falls in. Use a simplified state boundary polygon dataset (GeoJSON). Client-side or server-side. | M (3-5 days) | ~2MB GeoJSON for US state boundaries. Can use a lightweight point-in-polygon library. Only needs state-level accuracy. |

#### P1 -- Should-Have for v1

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Device management settings** | UI for the hunter to register their watch, view/regenerate API key, and see sync history (last sync time, success/failure). | M (3-5 days) | Trust-building feature. Hunter needs to know the link is working. |
| **Session detail view** | New page showing a single hunt session: map with flush locations, dog tracks, timeline of events, stats summary. Links to resulting harvest entries. | L (2-3 weeks) | High-value analytics feature. Makes the ecosystem feel integrated. |
| **Dog performance dashboard** | Season-level dog performance analytics: points per hunt, flush success from points, average range, comparison between dogs. | M (1-2 weeks) | Uses dog_data JSONB from hunt_sessions. Unique differentiator -- no other hunting app does this well. |
| **FIT file upload (Option B fallback)** | Upload form in Covey Ledger that accepts a .FIT file, parses it for UplandHunter custom fields, and creates draft entries. | M (1-2 weeks) | Backup import path. Use fit-file-parser npm library. |

#### P2 -- Nice-to-Have Future

| Gap | Description | Effort | Notes |
|---|---|---|---|
| **Push daily limits to watch** | API endpoint that returns compact regulation summary for the active state, consumed by the watch via makeWebRequest on hunt start. | S (2-3 days) | Pairs with UplandHunter P2 feature. |
| **Location heatmap** | Aggregate flush GPS data across sessions to show heatmap of productive hunting areas by species. | L (2-3 weeks) | Compelling feature for multi-season hunters. Requires map library (Mapbox or Leaflet). |
| **Export compliance report (PDF)** | Generate a printable compliance report showing harvest, possession, and freezer state. Useful if stopped by a game warden. | M (1-2 weeks) | Already in Covey Ledger future roadmap. |
| **Mobile app (PWA or React Native)** | Make Covey Ledger accessible as a mobile app for in-truck review. | XL (4-8 weeks) | Opens door to Option D (companion app) integration. |

---

## 6. Go-to-Market Readiness

### 6.1 Connect IQ Store Submission Requirements

UplandHunter is feature-complete and compiles clean at 176KB, but several items must be addressed before submitting to the Connect IQ Store.

#### Required Assets

| Asset | Status | Action Needed |
|---|---|---|
| **App Icon** | BLOCKED -- placeholder 40x40 orange square | Create proper icon. Required sizes: 35x35 (legacy), 40x40 (standard), 60x60 (high-res), 80x80 (banner). Design: bird silhouette or crossed shotguns on orange background. Must be visually distinct at 35x35. |
| **Store Screenshots** | NOT STARTED | Capture 4-6 screenshots from the simulator: (1) Main hunt screen with dog list, (2) Flush workflow species selection, (3) Navigation to downed bird, (4) Map view with waypoints, (5) Session stats summary, (6) Post-hunt summary. Must be actual device resolution (454x454 for Fenix 8). |
| **Store Description** | NOT STARTED | Write a compelling description (max 4000 chars). Cover: what it does, who it is for, key features, Alpha/Astro compatibility note, offline capability. Include keywords: upland, bird, hunting, dog tracking, Alpha, Astro, flush, pheasant, quail. |
| **Privacy Policy** | NOT STARTED | Required for apps that use Positioning, Sensor, or ANT+ permissions. Must describe: what data is collected (GPS position, sensor data), how it is used (on-device only, no cloud transmission in v1), whether data is shared (no, except FIT file to Garmin Connect). Host as a page on zachmartens.com. |
| **Developer Account** | UNKNOWN | Verify Garmin Developer account is active and can publish apps. Complete any required agreements. |
| **App Category** | NOT SET | Category: "Others" or "Navigation" (no "Hunting" category exists). |
| **What's New** | NOT STARTED | Initial release notes describing key features. |
| **Support URL** | NOT SET | Link to README_USER.md hosted on GitHub or zachmartens.com. |
| **Source URL** | OPTIONAL | Link to GitHub repo if open-sourcing. |

#### ANT+ Review Process

Because UplandHunter uses ANT+ (the `Ant` permission), it requires additional review by Garmin's ANT team. This adds time to the submission process.

**Requirements for ANT+ apps:**
1. The app must implement `Sensor.SensorDelegate` for System 8 native pairing (already done -- `DogTrackerPairingDelegate` exists).
2. The app must handle ANT+ channel errors gracefully (already done -- auto-reconnect on search timeout and channel close).
3. The app must not interfere with other ANT+ connections on the device.
4. The ANT team may request documentation of the ANT+ protocol being used. Since the Alpha/Astro protocol is undocumented, this could be a friction point. Prepare a document explaining: "Uses ANT+ Generic Channel to receive broadcast data from Garmin Alpha/Astro handhelds with 'Broadcast Dog Data' enabled."
5. **Risk:** Garmin may reject the app if they consider the Alpha/Astro protocol proprietary. Mitigation: existing apps like ekutter's "Dog Tracker" have passed review, establishing precedent.

**Estimated review timeline:** 1-2 weeks for standard review, potentially longer for ANT+ review.

#### SDK Version Compliance

Per Garmin's 2025 announcements:
- Side-loaded apps on System 8 devices require SDK 7.4.3+. **Status: compliant** (built with SDK 8.4.1).
- Store uploads require minimum SDK 8.1. **Status: compliant** (built with SDK 8.4.1).

### 6.2 Pre-Submission Checklist

```
STORE ASSETS
[ ] Launcher icon at all required sizes (35, 40, 60, 80 px)
[ ] 4-6 screenshots captured from simulator at device resolution
[ ] Store description written and reviewed
[ ] Privacy policy written and hosted
[ ] Support URL set (zachmartens.com or GitHub)
[ ] App category selected
[ ] Release notes written

ANT+ REVIEW PREPARATION
[ ] SensorDelegate implemented (DogTrackerPairingDelegate)
[ ] ANT+ protocol documentation prepared for review team
[ ] Graceful channel error handling verified
[ ] No interference with other ANT+ connections

TECHNICAL READINESS
[ ] Zero compiler warnings on all 10 target devices
[ ] Binary size within limits (176KB -- well within)
[ ] All permissions justified and documented
[ ] Settings accessible via Garmin Connect Mobile
[ ] Activity type and FIT fields documented

TESTING
[ ] Simulator testing on all target device profiles
[ ] Field testing on primary device (Fenix 8 Solar)
[ ] Field testing with Alpha/Astro handheld (ANT+ validation)
[ ] Battery life test (8+ hour continuous use)
[ ] Edge case testing (GPS loss, ANT+ disconnect, rapid input)
```

### 6.3 Go-to-Market Timeline Estimate

| Task | Duration | Dependency |
|---|---|---|
| Create app icons | 1-2 days | None |
| Capture screenshots | 1 day | Simulator or device |
| Write store description | 1 day | None |
| Write privacy policy | 1 day | None |
| Set up support page | 1 day | zachmartens.com |
| Field testing (real hunt) | 1-3 days | Hunting season, Alpha/Astro hardware |
| Submit to Connect IQ Store | 1 day | All above complete |
| Standard review period | 1-2 weeks | Garmin |
| ANT+ team review | 1-2 weeks additional | Garmin ANT team |
| **Total to store availability** | **3-6 weeks** | Mostly blocked on Garmin review |

---

## 7. Phased Roadmap

### Phase 1: Independent Hardening (Weeks 1-3)

**Goal:** Get both products individually solid before connecting them. Fix known issues, prepare for store submission.

**No integration dependency -- both workstreams can happen in parallel.**

| Week | UplandHunter (Watch) | Covey Ledger (Web) |
|---|---|---|
| 1 | Fix known issues: MRU species sorting, covey size selector, unit tests | Add `hunt_sessions` table to Supabase schema. Add GPS-to-state resolution utility. |
| 2 | Create proper launcher icon. Capture store screenshots. Write store description. | Build species mapping configuration UI (watch codes to Covey Ledger species IDs). |
| 3 | Write privacy policy. Prepare ANT+ review documentation. Submit to Connect IQ Store. | Build import API endpoint (Edge Function) that accepts JSON payload, validates schema, stores in `import_queue` table. |

**Milestone:** UplandHunter submitted to Connect IQ Store. Covey Ledger has a working import API that can receive structured hunt data.

### Phase 2: Core Integration (Weeks 4-7)

**Goal:** Connect the watch to the web. Implement Option C (Communications module) on the watch and the draft review flow on the web.

| Week | UplandHunter (Watch) | Covey Ledger (Web) |
|---|---|---|
| 4 | Add dog performance stat accumulation during session (points count, flushes-from-points, average distance). | Build draft harvest review page: list of imported flushes, map showing locations, editable species/quantity fields. |
| 5 | Implement flush data serialization (WaypointManager to JSON Dictionary matching Data Contract). Add API key setting. | Draft review page continued: state auto-detection from GPS, manual override, compliance pre-check before commit. |
| 6 | Implement `Communications.makeWebRequest()` POST to Covey Ledger import API at end of hunt. Handle success/failure responses. Add sync status to post-hunt summary. | "Confirm & Save" flow: commit reviewed drafts through compliance engine, create harvest_entries, link to hunt_session. |
| 7 | Implement retry queue for failed syncs (persist pending payload to Object Store, retry on next hunt start or manual trigger). | Device management page: register device, view/regenerate API key, sync history log. |

**Milestone:** End-to-end data flow working. Hunter ends a hunt, watch sends data to Covey Ledger, hunter reviews drafts on web, compliance engine validates, harvest entries created.

### Phase 3: Analytics and Polish (Weeks 8-12)

**Goal:** Make the ecosystem feel like one product. Build the analytics and visualization layer.

| Week | UplandHunter (Watch) | Covey Ledger (Web) |
|---|---|---|
| 8-9 | Per-flush FIT data (lap records). This enables Option A/B integration paths and enriches Garmin Connect activity view. | Session detail view: map with flush locations, dog positions, timeline, stats summary. |
| 10 | Field testing with full integration loop. Bug fixes. | Dog performance dashboard: per-dog stats across sessions, points/hunt trend, range analysis. |
| 11 | -- | FIT file upload as fallback import path (Option B). |
| 12 | Final store update with integration features. | Integration testing, edge case handling, polish. |

**Milestone:** Covey Ledger shows a rich hunt history with maps, dog analytics, and compliance status. Both import paths (live sync + FIT upload) operational.

### Phase 4: Scale Readiness (Weeks 13-20)

**Goal:** If the products gain traction, invest in the Garmin Connect Developer Program integration and mobile access.

| Initiative | Effort | Dependency |
|---|---|---|
| Apply to Garmin Connect Developer Program | 1 week | Business developer application |
| Implement OAuth + webhook endpoint (Option A) | 3-4 weeks | Developer program approval |
| Push daily limits to watch (P2 feature) | 1-2 weeks | Phase 2 complete |
| Covey Ledger PWA for mobile access | 3-4 weeks | None |
| Location heatmap / multi-season analytics | 2-3 weeks | Phase 3 data accumulation |
| PDF compliance report export | 1-2 weeks | None |

### What Ships Independently vs. Together

| Deliverable | Ships Independently? | Notes |
|---|---|---|
| UplandHunter on Connect IQ Store | YES | All features work standalone. No Covey Ledger required. |
| Covey Ledger manual harvest entry | YES | Already working. No watch required. |
| Watch-to-web sync (Communications API) | NO | Requires changes to BOTH apps simultaneously. |
| Draft harvest review UI | NO | Requires import API + watch sync to have data to review. Can be built and tested with mock data. |
| Dog performance dashboard | PARTIALLY | Can show data from any source, but richest data comes from watch integration. |
| FIT file upload import | PARTIALLY | Covey Ledger feature, but requires UplandHunter FIT changes for per-flush data. Without per-flush FIT data, only gets summary stats. |

### Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Garmin rejects UplandHunter due to ANT+ protocol concerns | LOW-MEDIUM | HIGH | Reference ekutter's precedent. Offer to work with ANT team. Side-load fallback for personal use. |
| makeWebRequest() unreliable in low-connectivity hunting areas | HIGH | MEDIUM | Retry queue with Object Store persistence. Visual indicator so hunter knows sync status. FIT upload as fallback. |
| Species mapping mismatches cause incorrect compliance records | MEDIUM | HIGH | Draft review step catches errors before compliance commit. Hunter always confirms species before saving. |
| Garmin Connect Developer Program application denied | LOW | MEDIUM | Option C (Communications module) works without it. Developer program is Phase 4, not critical path. |
| FIT file does not reliably contain per-flush data | MEDIUM | LOW | Option C bypasses FIT entirely for primary data flow. FIT enrichment is a parallel nice-to-have. |
| Solo dev bandwidth insufficient for both apps | MEDIUM | MEDIUM | Phase 1 tasks are independent and can be interleaved. Phase 2 has hard dependencies -- block calendar for focused weeks. |

---

## Appendix A: Reference Architecture Diagram

```
+---------------------------+          +---------------------------+
|   UPLAND HUNTER WATCH     |          |      COVEY LEDGER WEB     |
|   (Garmin Connect IQ)     |          |    (React + Supabase)     |
|                           |          |                           |
|  +---------------------+ |          | +---------------------+   |
|  | Flush Workflow       | |          | | Import API          |   |
|  | (5-screen capture)   | |          | | (Edge Function)     |   |
|  +---------------------+ |          | +---------------------+   |
|            |              |          |           |               |
|  +---------------------+ |          | +---------------------+   |
|  | WaypointManager     | |  JSON    | | import_queue        |   |
|  | (Object Store)      |--+-------->| | (draft entries)     |   |
|  +---------------------+ |  POST    | +---------------------+   |
|            |              |  via     |           |               |
|  +---------------------+ |  BLE/    | +---------------------+   |
|  | Dog Tracker Sensor   | |  phone   | | Draft Review UI     |   |
|  | (ANT+ / Mock)       | |          | | (confirm/edit/map)  |   |
|  +---------------------+ |          | +---------------------+   |
|            |              |          |           |               |
|  +---------------------+ |          | +---------------------+   |
|  | FIT Activity File   | |          | | Compliance Engine   |   |
|  | (Garmin Connect)    | |          | | (server-side)       |   |
|  +---------------------+ |          | +---------------------+   |
|            |              |          |           |               |
|  +---------------------+ |          | +---------------------+   |
|  | Session Stats /     | |          | | harvest_entries     |   |
|  | Post-Hunt Summary   | |          | | hunt_sessions       |   |
|  +---------------------+ |          | | Dashboard / History |   |
+---------------------------+          | +---------------------+   |
                                       +---------------------------+
```

## Appendix B: Species Code Reference

| Code | Enum Constant | Display Name | Covey Ledger Default Mapping |
|---|---|---|---|
| 0 | SPECIES_PHEASANT | Pheasant | Pheasant |
| 1 | SPECIES_QUAIL | Quail | Quail (user may remap to subspecies) |
| 2 | SPECIES_CHUKAR | Chukar | Chukar |
| 3 | SPECIES_GROUSE_RUFFED | Grouse (Ruffed) | Grouse (Ruffed) |
| 4 | SPECIES_GROUSE_SAGE | Grouse (Sage) | Grouse (Sage) |
| 5 | SPECIES_GROUSE_SHARPTAIL | Grouse (Sharp-tail) | Grouse (Sharp-tailed) |
| 6 | SPECIES_WOODCOCK | Woodcock | Woodcock |
| 7 | SPECIES_PRAIRIE_CHICKEN | Prairie Chicken | Prairie Chicken |
| 8 | SPECIES_PARTRIDGE | Partridge | Partridge (Hungarian) |
| 9 | SPECIES_DOVE | Dove | Dove |
| 10 | SPECIES_OTHER | Other | REQUIRES MANUAL ASSIGNMENT |

## Appendix C: Existing Data Models Cross-Reference

### UplandHunter Waypoint (Monkey C)

```
Waypoint {
  id: Number (Unix timestamp)
  latitude: Double
  longitude: Double
  timestamp: Number (Unix)
  species: Number (0-10 enum)
  quantityFlushed: Number
  birdsDown: Number
  shotResult: Number (0=hit, 1=missed, 2=no_shot)
  coveySize: Number? (nullable)
  dogOnPoint: Boolean
  dogName: String? (nullable)
}
```

### Covey Ledger harvest_entries (Supabase/PostgreSQL)

```
harvest_entries {
  id: UUID (auto-generated)
  user_id: UUID (from auth)
  state_id: UUID (references states)
  species_id: UUID (references species)
  quantity: Number
  date: String (YYYY-MM-DD)
  notes: String? (nullable)
  created_at: Timestamp (auto)
}
```

### Required New Fields on harvest_entries for Integration

```
source: TEXT ('manual' | 'upland_hunter_watch')
source_flush_id: BIGINT (deduplication key, nullable)
source_session_id: TEXT (links to hunt_sessions, nullable)
latitude: NUMERIC(10,7) (nullable, for map display)
longitude: NUMERIC(10,7) (nullable, for map display)
```

These fields are nullable and backward-compatible. Existing manual entries continue to work unchanged.
