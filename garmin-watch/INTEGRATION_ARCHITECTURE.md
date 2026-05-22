# UplandHunter <> CoveyTracker Integration Architecture

**Version:** 1.0 | **Date:** 2026-03-26
**Author:** Zach Martens | **Status:** Proposed
**Systems:** UplandHunter (Garmin Connect IQ) + CoveyTracker (React + Supabase)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Context](#2-system-context)
3. [Data Flow Architecture](#3-data-flow-architecture)
4. [Integration Pattern Evaluation](#4-integration-pattern-evaluation)
5. [Recommended Architecture](#5-recommended-architecture)
6. [Schema Mapping](#6-schema-mapping)
7. [API Design](#7-api-design)
8. [Migration Path](#8-migration-path)
9. [Architecture Decision Records](#9-architecture-decision-records)
10. [Implementation Sequence](#10-implementation-sequence)

---

## 1. Executive Summary

UplandHunter records bird flushes on a Garmin watch. CoveyTracker manages harvest compliance on the web. The goal is to flow hunt data from wrist to compliance ledger without double-entry.

**The core problem:** A hunter records "2 pheasants downed" on their watch during a hunt. That data currently lives in two places (Garmin Object Store and FIT file) but never reaches CoveyTracker, where it needs to exist as a `harvest_entry` for compliance tracking.

**Recommended approach:** A Supabase Edge Function that accepts hunt summary data, combined with a manual "Sync to Covey" button in CoveyTracker's UI. The watch exports data via FIT file to Garmin Connect. CoveyTracker fetches and parses it, or the user enters data from the post-hunt summary screen. No Connect IQ companion app required for MVP.

**Why this approach wins:** It requires zero changes to UplandHunter's Monkey C code for the MVP path, uses infrastructure Zach already pays for (Supabase), and avoids Garmin's API approval process entirely. The more automated paths (companion app, Garmin webhooks) are documented below as future upgrades.

---

## 2. System Context

### Current State — Two Isolated Systems

```
                    UplandHunter (Watch)                    CoveyTracker (Web)
                    ====================                    ==================
Records:            Flushes (species, qty,                  Harvest entries
                    shot result, birds down,                (state, species, qty,
                    GPS coords, timestamp)                  date, notes)

Stores:             Object Store (in-app)                   Supabase Postgres
                    FIT file (activity)                     (harvest_entries,
                                                            distributions,
                                                            consumptions)

Syncs to:           Garmin Connect (cloud)                  Nowhere (web-only)

Auth:               None (single-user device)               Supabase email/password

Missing link:       No way to export data                   No way to import data
                    to CoveyTracker                         from UplandHunter
```

### What UplandHunter Captures That CoveyTracker Needs

| UplandHunter Field | CoveyTracker Equivalent | Notes |
|---|---|---|
| `birdsDown` (Number) | `harvest_entries.quantity` | Only downed birds count as harvest |
| `species` (enum 0-10) | `harvest_entries.species_id` (UUID) | Requires mapping table |
| `timestamp` (Unix) | `harvest_entries.date` (date) | Extract date from timestamp |
| GPS lat/lon | **Not captured** | Could auto-detect state |
| `shotResult` | **Not captured** | Useful metadata, not compliance-relevant |
| `quantityFlushed` | **Not captured** | Interesting for analytics, not compliance |

### What UplandHunter Does NOT Capture

| CoveyTracker Field | Why It Is Missing | Resolution |
|---|---|---|
| `state_id` | Watch has no state regulation awareness | User selects state during import |
| `species_id` (UUID) | Watch uses integer enums | Mapping table at import time |
| `notes` | Watch UI too constrained | User adds during import review |

---

## 3. Data Flow Architecture

### 3.1 Complete Pipeline: Wrist to Compliance Ledger

```
 FIELD                    PHONE                     CLOUD                    WEB
 =====                    =====                     =====                    ===

 [Garmin Watch]           [Garmin Connect           [Garmin Connect          [CoveyTracker]
  UplandHunter             Mobile App]               Cloud]                  covey.zachmartens.com
  |                        |                         |                       |
  |--flush workflow------->|                         |                       |
  |  (species, qty,        |                         |                       |
  |   shot, birds down,    |                         |                       |
  |   GPS, timestamp)      |                         |                       |
  |                        |                         |                       |
  |--Object Store--------->|  (data stays on watch)  |                       |
  |  (persists waypoints)  |                         |                       |
  |                        |                         |                       |
  |--FIT file (on          |                         |                       |
  |  activity end)-------->|--Bluetooth sync--------->|                      |
  |                        |  (FIT file uploads      |  (activity stored     |
  |                        |   to Garmin Connect)    |   with custom fields) |
  |                        |                         |                       |
  |                        |                         |    -- PATH A --       |
  |                        |                         |                       |
  |                        |                         |  [Garmin Health API]  |
  |                        |                         |  (requires business   |
  |                        |                         |   approval + OAuth +  |
  |                        |                         |   webhook endpoint)   |
  |                        |                         |        |              |
  |                        |                         |        v              |
  |                        |                         |  [Edge Function]----->|
  |                        |                         |  parse FIT,           |
  |                        |                         |  create harvest_entry |
  |                        |                         |                       |
  |                        |                         |    -- PATH B --       |
  |                        |                         |                       |
  |                        |                         |  User downloads FIT   |
  |                        |                         |  from connect.garmin  |
  |                        |                         |  .com, uploads to     |
  |                        |                         |  CoveyTracker-------->|
  |                        |                         |                       |
  |                        |    -- PATH C --         |                       |
  |                        |                         |                       |
  |                        |  [Connect IQ            |                       |
  |                        |   Companion App]        |                       |
  |                        |  Communications.transmit|                       |
  |                        |  watch -> phone -> API  |----- direct POST ---->|
  |                        |                         |                       |
  |                        |    -- PATH D --         |                       |
  |                        |                         |                       |
  |                        |  User reads post-hunt   |                       |
  |                        |  summary on watch,      |                       |
  |                        |  manually enters in     |                       |
  |                        |  CoveyTracker-----------|----- manual entry --->|
```

### 3.2 Data Lifecycle Within UplandHunter

Understanding when data is available at each stage:

```
Timeline of a Hunt:

  START HUNT
      |
      |--- Activity recording begins (FIT file created)
      |--- GPS tracking begins
      |--- ANT+ dog tracker connects
      |
      v
  FLUSH #1 (pheasant, 2 flushed, 1 downed)
      |--- Waypoint saved to Object Store immediately
      |--- FIT custom fields updated (total_flushes=1, total_birds_down=1)
      |--- GPS trackpoint continues logging to FIT
      |
  FLUSH #2 (quail, 8 flushed covey, 0 downed - missed)
      |--- Waypoint saved to Object Store
      |--- FIT custom fields updated (total_flushes=2, total_birds_down=1)
      |
  FLUSH #3 (pheasant, 1 flushed, 1 downed)
      |--- Waypoint saved to Object Store
      |--- FIT custom fields updated (total_flushes=3, total_birds_down=2)
      |
  END HUNT
      |--- PostHuntSummaryView shown (species breakdown displayed)
      |--- User presses SELECT -> stopHuntActivity()
      |--- _session.stop() + _session.save() -> FIT file written to watch storage
      |--- FIT file queued for Garmin Connect sync
      |
  PHONE SYNC (next Bluetooth connection)
      |--- FIT file uploaded to Garmin Connect cloud
      |--- Activity appears in Garmin Connect with custom developer fields
      |
  DATA AVAILABLE FOR IMPORT
      |--- FIT file accessible via Garmin Health API (if approved)
      |--- FIT file downloadable from connect.garmin.com (manual)
      |--- Object Store waypoints still on watch (until cleared or overwritten)
```

### 3.3 FIT File Contents — What Is Actually Recorded

The FIT file from UplandHunter contains:

**Standard FIT fields** (automatic via ActivityRecording):
- Activity type: SPORT_HIKING / SUB_SPORT_GENERIC
- Activity name: "Upland Hunt"
- Start time, end time, duration
- GPS track (lat/lon/altitude at each recording interval)
- Distance traveled
- Heart rate (if HR strap paired)

**Custom developer fields** (via FitContributor):
- `total_flushes` (field ID 0, UINT16) — session total
- `total_birds_down` (field ID 1, UINT16) — session total
- `shots_taken` (field ID 2, UINT16) — session total

**What is NOT in the FIT file:**
- Per-flush breakdown (species, individual quantities, GPS per flush)
- Shot result per flush (hit/miss/no-shot)
- Covey size
- Dog tracking data
- Individual waypoint details

This is a critical constraint. The FIT file only has session-level aggregates, not the per-species detail that CoveyTracker needs for compliance. The per-species data lives only in the Object Store on the watch.

---

## 4. Integration Pattern Evaluation

### Pattern A: Garmin Health API / Connect API Webhook Pipeline

**How it would work:**
1. Register as a Garmin Health API partner (business developer account)
2. Implement OAuth flow for user authorization
3. Garmin sends webhook POST to your endpoint when a new activity syncs
4. Edge Function receives the webhook, fetches the FIT file via API
5. Parse FIT file, extract custom fields, create harvest_entries

**Feasibility assessment:**

| Factor | Assessment |
|---|---|
| API access | Garmin Health API requires business partnership approval. Not available to individual developers. Garmin Connect API (consumer) has no documented public access. |
| OAuth complexity | Full OAuth 2.0 flow with token refresh. Requires a backend endpoint for the callback. |
| Webhook endpoint | Need a publicly accessible HTTPS endpoint. Supabase Edge Function or Cloudflare Worker could serve. |
| FIT file access | Even with API access, the FIT file only contains session aggregates (total_flushes, total_birds_down), not per-species breakdown. |
| Data completeness | **Insufficient.** FIT custom fields lack per-species detail. Would only get "3 flushes, 2 birds down" — not "1 pheasant + 1 quail downed." |
| Timeline | Weeks to months for API approval. May be denied for personal/hobby use. |

**Verdict: NOT RECOMMENDED for MVP.** The Garmin Health API is gated behind business partnerships, and even if approved, the FIT file lacks the per-species granularity CoveyTracker needs. This path only becomes viable if UplandHunter adds per-flush lap records to the FIT file (see Section 8.1).

---

### Pattern B: Connect IQ Companion App (Communications Module)

**How it would work:**
1. Add Communications module code to UplandHunter's Monkey C
2. On hunt end (or per-flush), transmit waypoint data from watch to phone
3. Phone's Garmin Connect Mobile app receives the data
4. A companion widget/glance (or the Garmin Connect IQ phone app) forwards data to CoveyTracker's API
5. Supabase Edge Function receives and processes the import

**Feasibility assessment:**

| Factor | Assessment |
|---|---|
| Connect IQ Communications API | Available. `Communications.transmit()` sends data to the paired phone. `Communications.makeWebRequest()` can POST directly to an HTTPS endpoint from the watch (via phone's internet connection). |
| `makeWebRequest()` | Can POST JSON directly to a Supabase Edge Function. Limited to 16KB payload, but hunt data is well under that. Requires the phone to be connected via Bluetooth at the time of the call. |
| Phone companion app | NOT required if using `makeWebRequest()`. A companion app is only needed for complex phone-side processing. |
| Data completeness | **Full control.** Can serialize all waypoint data (species, quantities, GPS) from Object Store and send it. |
| Watch-side complexity | Moderate. Need to add Communications permission, serialize waypoints to JSON-like dictionary, handle send success/failure. Estimated 150-250 lines of Monkey C. |
| Connectivity requirement | Requires Bluetooth connection to phone AND phone internet access. Not available in backcountry without cell service. Data would need to queue and retry. |
| Auth challenge | The watch has no concept of Supabase auth tokens. Would need a pre-shared API key or a service-role key in the watch app (security risk if app is published to Connect IQ store). |

**Verdict: STRONG OPTION for V2.** This is the most automated path that provides full data fidelity. The main risk is the connectivity requirement (no cell service during hunts) and the auth token management. Best implemented after the manual bridge is working and validated.

---

### Pattern C: FIT File Upload (Manual Bridge)

**How it would work:**
1. After a hunt, user syncs watch to Garmin Connect (automatic via phone)
2. User visits CoveyTracker, clicks "Import from Garmin"
3. User downloads the FIT file from connect.garmin.com (Export Original)
4. User uploads FIT file to CoveyTracker
5. CoveyTracker parses the FIT file client-side using a JavaScript FIT parser
6. Displays extracted data for user review (add state, confirm species mapping)
7. User confirms, data saved as harvest_entries

**Feasibility assessment:**

| Factor | Assessment |
|---|---|
| FIT parsing in JS | Libraries exist: `fit-file-parser` (npm), `easy-fit` (npm). Both parse FIT binary format including developer fields. |
| Data in FIT file | **Session aggregates only** — total_flushes, total_birds_down, shots_taken. No per-species breakdown. |
| User experience | Clunky. Download FIT from Garmin website, upload to CoveyTracker. Multiple steps across two websites. |
| Per-species gap | Fatal for single-species hunts (e.g., "2 pheasants downed" is sufficient). Insufficient for multi-species hunts (e.g., "1 pheasant + 1 quail" — FIT only says "2 birds down total"). |
| Offline capability | FIT file is available on the phone after sync. Could work with a PWA that reads local files. |

**Verdict: PARTIAL SOLUTION.** Useful as a supplementary data source (confirms hunt happened, provides GPS track, total counts), but cannot be the primary import path due to missing per-species data. Unless we enhance the FIT recording (see Pattern C-Enhanced below).

---

### Pattern C-Enhanced: FIT File with Per-Flush Lap Records

**How it would work:**
1. Modify UplandHunter to write a FIT "lap" record for each flush event
2. Each lap contains custom fields: species, quantity_flushed, birds_down, shot_result, lat, lon
3. FIT file now contains full per-flush detail
4. Same upload flow as Pattern C, but with complete data

**Feasibility assessment:**

| Factor | Assessment |
|---|---|
| FIT lap records | Connect IQ's `ActivityRecording.Session.addLap()` creates a lap boundary. Custom fields with `MESG_TYPE_LAP` attach data to each lap. This is a proven pattern. |
| Data completeness | **Full.** Each flush becomes a lap with all fields. FIT parser can extract per-lap custom fields. |
| Watch-side changes | Moderate. Add lap-level FitContributor fields and call `addLap()` in the flush confirmation. Estimated 50-80 lines of Monkey C. |
| FIT file size | Minimal increase. Each lap adds ~100 bytes. 20 flushes = 2KB extra. |
| JS parsing | `fit-file-parser` and `easy-fit` both support lap records and developer fields. |

**Verdict: STRONG OPTION.** This solves the data completeness problem at the source. Combined with a FIT upload UI in CoveyTracker, this provides a reliable, offline-capable import path.

---

### Pattern D: Manual Entry from Post-Hunt Summary

**How it would work:**
1. Hunter ends the hunt on the watch
2. PostHuntSummaryView displays species breakdown: "Pheasant 4/2, Quail 3/1"
3. Hunter opens CoveyTracker on phone, enters the numbers manually
4. CoveyTracker validates against compliance engine, saves

**Feasibility assessment:**

| Factor | Assessment |
|---|---|
| Implementation cost | Zero. Both systems already exist. No code changes needed. |
| Data completeness | Full, because the human is the bridge. They can see per-species breakdown on the watch and type it into CoveyTracker. |
| Error rate | Moderate. Humans make transcription errors, especially with cold hands after a long hunt day. |
| User experience | Tolerable for MVP. Hunter already reviews the summary screen. Adding 60 seconds of data entry is acceptable for a solo user. |
| Offline capability | CoveyTracker needs internet. Watch data is always available. |

**Verdict: MVP BASELINE.** This is what happens today (or would happen). Zero engineering effort, full data fidelity, acceptable UX for a single user. Every other pattern should be measured against the improvement it provides over this baseline.

---

### Comparison Matrix

| Criterion | A: Garmin API | B: Companion Comm | C: FIT Upload | C+: FIT Laps | D: Manual |
|---|---|---|---|---|---|
| Data completeness | Low (aggregates) | High (full) | Low (aggregates) | High (full) | High (human) |
| Implementation effort | Very High | Medium-High | Medium | Medium | None |
| UplandHunter changes | None | Yes (150+ LOC) | None | Yes (50-80 LOC) | None |
| CoveyTracker changes | Edge Function | Edge Function | Import UI + parser | Import UI + parser | None |
| Infrastructure needed | Webhook endpoint | None (direct POST) | None | None | None |
| External dependencies | Garmin API approval | Phone BT + internet | Garmin Connect web | Garmin Connect web | None |
| Offline-capable | No | No (needs phone) | Yes (file-based) | Yes (file-based) | Partial |
| Error-prone | Low (automated) | Low (automated) | Low (parsed) | Low (parsed) | Moderate |
| Time to implement | Months | 2-3 weeks | 1-2 weeks | 2-3 weeks | 0 |

---

## 5. Recommended Architecture

### Phase 1 (MVP): Manual Entry + FIT Lap Enhancement

This is a two-part approach that provides immediate value with minimal risk.

**Part 1 — Manual entry (available now, zero effort):**
The hunter reads the PostHuntSummaryView on the watch and enters numbers into CoveyTracker. This works today.

**Part 2 — FIT file with per-flush laps (2-3 weeks of work):**
Enhance UplandHunter to write per-flush lap records into the FIT file. Build a FIT import page in CoveyTracker. The hunter downloads the FIT from Garmin Connect, uploads it, reviews the mapped data, selects a state, and saves.

### Phase 2 (V2): Direct Watch-to-Cloud via Communications API

Add `Communications.makeWebRequest()` to UplandHunter so it can POST hunt data directly to a Supabase Edge Function when the hunt ends and the phone is connected. This eliminates the FIT download/upload step entirely.

### System Diagram — Phase 1

```
                                  PHASE 1 ARCHITECTURE
                                  ====================

  [Garmin Watch]                                          [CoveyTracker]
  UplandHunter                                            covey.zachmartens.com
  +-----------------+                                     +-------------------+
  | Flush Workflow   |                                     | Import Page       |
  | -> Waypoint      |                                     | (new)             |
  |    saved to      |                                     |                   |
  |    Object Store  |                                     | 1. Upload .FIT    |
  |                  |                                     | 2. Parse laps     |
  | End Hunt:        |                                     | 3. Show species   |
  |  -> addLap()     |     FIT file (via Garmin Connect)   |    breakdown      |
  |     per flush    |  ================================>  | 4. Select state   |
  |  -> session.save |     (manual download + upload)      | 5. Review & map   |
  |  -> FIT file     |                                     | 6. Save entries   |
  |     with laps    |                                     |        |          |
  +-----------------+                                     |        v          |
                                                          | [Supabase]        |
                                                          |  validate_harvest |
                                                          |  _entry() check   |
                                                          |  -> insert        |
                                                          |  harvest_entries  |
                                                          +-------------------+
```

### System Diagram — Phase 2

```
                                  PHASE 2 ARCHITECTURE
                                  ====================

  [Garmin Watch]        [Phone]             [Supabase]         [CoveyTracker]
  UplandHunter          Garmin Connect      Edge Function       Web App
  +------------+        Mobile              +-------------+    +-------------+
  | End Hunt    |        +---------+         | POST        |    | Dashboard   |
  |             |        |         |         | /import-hunt|    | shows new   |
  | serialize   |  BT    | forward |  HTTPS  |             |    | entries     |
  | waypoints   |------->| request |-------->| validate    |    |             |
  | makeWeb     |        | to API  |         | map species |    | Import page |
  | Request()   |        |         |         | check       |    | still works |
  | POST to     |        +---------+         | compliance  |    | as fallback |
  | Edge Fn     |                            | insert rows |    |             |
  +------------+                            +------+------+    +------+------+
                                                   |                  ^
                                                   |   Supabase DB    |
                                                   +------------------+
```

---

## 6. Schema Mapping

### 6.1 Species Mapping Table

UplandHunter uses integer enums. CoveyTracker uses UUID-keyed rows. A mapping table bridges them.

**UplandHunter species enum (Constants.mc):**

| Enum Value | Name |
|---|---|
| 0 | Pheasant |
| 1 | Quail |
| 2 | Chukar |
| 3 | Grouse (Ruffed) |
| 4 | Grouse (Sage) |
| 5 | Grouse (Sharp-tail) |
| 6 | Woodcock |
| 7 | Prairie Chicken |
| 8 | Partridge |
| 9 | Dove |
| 10 | Other |

**CoveyTracker species table (seeded):**

| Name |
|---|
| Pheasant |
| Quail |
| Grouse |
| Prairie Chicken |
| Partridge |
| Turkey |
| Woodcock |
| Dove |
| Chukar |
| Sharp-tailed Grouse |

**Mapping challenges:**

1. **Grouse granularity mismatch.** UplandHunter distinguishes Ruffed Grouse, Sage Grouse, and Sharp-tailed Grouse. CoveyTracker has "Grouse" and "Sharp-tailed Grouse" as separate entries. Ruffed Grouse and Sage Grouse would both map to "Grouse" — but state regulations may differ by grouse subspecies.

2. **Missing species in CoveyTracker.** UplandHunter has "Other" (enum 10). CoveyTracker has no catch-all. Also, CoveyTracker has "Turkey" which UplandHunter does not track.

3. **Name variations.** UplandHunter uses "Grouse (Sharp-tail)" while CoveyTracker uses "Sharp-tailed Grouse". These are the same bird.

**Recommended mapping (stored in CoveyTracker as a config table or JSON constant):**

```typescript
// species_mapping.ts — maps UplandHunter enum to CoveyTracker species name
const UPLAND_HUNTER_SPECIES_MAP: Record<number, string> = {
  0: 'Pheasant',
  1: 'Quail',
  2: 'Chukar',
  3: 'Grouse',            // Ruffed Grouse -> Grouse
  4: 'Grouse',            // Sage Grouse -> Grouse (see note below)
  5: 'Sharp-tailed Grouse',
  6: 'Woodcock',
  7: 'Prairie Chicken',
  8: 'Partridge',
  9: 'Dove',
  10: null,               // "Other" -> requires manual selection
};
```

**Important decision:** Sage Grouse regulations differ significantly from Ruffed Grouse in most states. CoveyTracker should add "Sage Grouse" and "Ruffed Grouse" as distinct species entries to match UplandHunter's granularity. This is a schema change in CoveyTracker's species seed data.

### 6.2 Flush Record to harvest_entry Mapping

For each flush where `birdsDown > 0`:

| UplandHunter Waypoint | Transformation | CoveyTracker harvest_entry |
|---|---|---|
| `birdsDown` | Direct | `quantity` |
| `species` (enum) | Lookup via mapping table | `species_id` (UUID) |
| `timestamp` (Unix) | Extract date portion | `date` |
| GPS `latitude`, `longitude` | Reverse geocode to state | `state_id` (UUID) |
| — | User selects during review | `state_id` (fallback) |
| `shotResult`, `quantityFlushed`, `coveySize` | Concatenate as metadata | `notes` |
| — | From auth session | `user_id` |

**Rules:**
- Only flushes with `birdsDown > 0` create harvest_entries. Misses and no-shots are not harvests.
- Multiple flushes of the same species on the same day in the same state should be individual entries (not aggregated), because the compliance engine validates each entry against remaining capacity.
- The `shotResult == SHOT_HIT` check is redundant with `birdsDown > 0` but provides an extra safety filter.

### 6.3 GPS Coordinates to State Auto-Detection

GPS coordinates can be reverse geocoded to determine which US state the hunter was in.

**Options for reverse geocoding:**

1. **Client-side point-in-polygon.** Ship a simplified US state boundary GeoJSON (~200KB minified). Check which polygon contains the GPS point. No API call needed. Works offline.

2. **Nominatim API** (OpenStreetMap). Free, no API key. Rate-limited to 1 req/sec. `GET https://nominatim.openstreetmap.org/reverse?lat=X&lon=Y&format=json` returns `address.state`.

3. **Hardcoded lookup.** For a single user who hunts in known states, a bounding box check is sufficient. Kansas, South Dakota, etc. have simple rectangular-ish boundaries.

**Recommendation:** Option 1 (client-side point-in-polygon) for reliability. Option 2 as a fallback. The auto-detected state should be pre-selected in the import review UI but always editable — the hunter knows where they were.

### 6.4 Handling Multi-Species Hunts

A single hunt session may contain flushes of multiple species. The import should produce one `harvest_entry` per species per state per day (or one per flush, aggregated by the user's choice).

**Example:**
```
Hunt session on 2026-11-15 in Kansas:
  Flush 1: Pheasant, 2 flushed, 1 downed (SHOT_HIT)
  Flush 2: Quail (covey 12), 12 flushed, 0 downed (SHOT_MISSED)
  Flush 3: Pheasant, 1 flushed, 1 downed (SHOT_HIT)
  Flush 4: Quail (covey 8), 8 flushed, 2 downed (SHOT_HIT)

Import produces:
  harvest_entry: Kansas, Pheasant, quantity=2, date=2026-11-15
  harvest_entry: Kansas, Quail, quantity=2, date=2026-11-15
```

The import UI should aggregate by species (2 pheasant flushes -> 1 entry with quantity 2) and show the breakdown for review before saving. Each entry runs through `validate_harvest_entry()` before insertion.

---

## 7. API Design

### 7.1 Import Endpoint — Supabase Edge Function

**Decision: Supabase Edge Function over Cloudflare Worker.**

Rationale: CoveyTracker already uses Supabase for auth, database, and server functions. An Edge Function can access the database directly using the service role key, participate in RLS, and call existing Postgres functions (validate_harvest_entry). Adding a Cloudflare Worker would introduce a second infrastructure provider, a second deployment pipeline, and require managing Supabase credentials in Cloudflare's secrets.

**Function name:** `import-hunt`

**Authentication:** Supabase JWT from the logged-in CoveyTracker session. The Edge Function validates the JWT and extracts the user_id.

### 7.2 Request/Response Schema

```typescript
// POST /functions/v1/import-hunt

// Request body
interface ImportHuntRequest {
  /** Source of the data — for logging and future extensibility */
  source: 'fit_upload' | 'manual' | 'watch_direct';

  /** The date of the hunt (ISO 8601 date string) */
  hunt_date: string;

  /** State where the hunt occurred (CoveyTracker state UUID) */
  state_id: string;

  /** Array of harvest entries to create */
  entries: ImportEntry[];

  /** Idempotency key — prevents duplicate imports of the same hunt.
   *  For FIT uploads: SHA-256 hash of the FIT file.
   *  For watch_direct: session start timestamp.
   *  For manual: omit (each submit is intentional). */
  idempotency_key?: string;

  /** Optional metadata from the hunt session */
  session_metadata?: {
    duration_seconds?: number;
    distance_meters?: number;
    total_flushes?: number;
    total_shots?: number;
    gps_track?: Array<{ lat: number; lon: number; time: number }>;
  };
}

interface ImportEntry {
  /** CoveyTracker species UUID (resolved by the client from the mapping) */
  species_id: string;

  /** Number of birds downed (the harvest quantity) */
  quantity: number;

  /** Optional notes — auto-generated from flush metadata */
  notes?: string;
}

// Response body (success)
interface ImportHuntResponse {
  success: true;
  entries_created: number;
  compliance_results: Array<{
    species_id: string;
    species_name: string;
    quantity: number;
    blocked: boolean;
    daily_remaining: number | null;
    possession_remaining: number | null;
    explanation: string;
  }>;
  /** Set to true if this idempotency_key was already processed */
  duplicate: boolean;
}

// Response body (error)
interface ImportHuntErrorResponse {
  success: false;
  error: string;
  /** If some entries were blocked by compliance, partial_results shows which */
  partial_results?: Array<{
    species_id: string;
    blocked: boolean;
    explanation: string;
  }>;
}
```

### 7.3 Edge Function Logic

```
import-hunt Edge Function pseudocode:

1. Authenticate: verify JWT, extract user_id
2. Validate request body schema
3. Check idempotency_key:
   a. Query hunt_imports table for matching key
   b. If found: return { success: true, duplicate: true, ... previous result }
   c. If not found: continue
4. For each entry in entries[]:
   a. Call validate_harvest_entry(state_id, species_id, quantity, hunt_date)
   b. If blocked: add to partial_results, mark overall as blocked
   c. If allowed: queue for insertion
5. If any entry blocked:
   a. Return error with partial_results (no entries inserted)
   b. Rationale: all-or-nothing import prevents partial hunt states
6. If all entries pass:
   a. Insert all harvest_entries in a single transaction
   b. Insert hunt_import record with idempotency_key and results
   c. Return success with compliance_results
```

### 7.4 Idempotency — Preventing Double Imports

A new table tracks processed imports:

```sql
CREATE TABLE IF NOT EXISTS hunt_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  source text NOT NULL, -- 'fit_upload', 'manual', 'watch_direct'
  hunt_date date NOT NULL,
  state_id uuid NOT NULL REFERENCES states(id),
  entries_created integer NOT NULL,
  result_data jsonb, -- full response stored for duplicate returns
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, idempotency_key)
);
```

For FIT file uploads, the idempotency key is a SHA-256 hash of the file contents. Re-uploading the same FIT file returns the previous result without creating duplicate entries.

For watch-direct imports (Phase 2), the key is the hunt session start timestamp (Unix), which is unique per hunt.

### 7.5 Error Handling

| Scenario | HTTP Status | Response |
|---|---|---|
| Invalid/missing JWT | 401 | `{ success: false, error: "Not authenticated" }` |
| Malformed request body | 400 | `{ success: false, error: "Invalid request: ..." }` |
| Unknown species_id | 400 | `{ success: false, error: "Unknown species: ..." }` |
| Unknown state_id | 400 | `{ success: false, error: "Unknown state: ..." }` |
| Compliance blocked | 409 | `{ success: false, error: "Compliance check failed", partial_results: [...] }` |
| Duplicate import | 200 | `{ success: true, duplicate: true, ... }` |
| Database error | 500 | `{ success: false, error: "Internal error" }` (no details leaked) |

---

## 8. Migration Path

### 8.1 UplandHunter Changes (Monkey C)

#### Phase 1: Add FIT Lap Records per Flush

**Files to modify:** `source/UplandHunterApp.mc`, `source/FlushWorkflow/ConfirmationView.mc`

**Changes to UplandHunterApp.mc:**

Add lap-level FIT custom fields (in addition to existing session-level fields):

```
// New FIT fields — per-lap (one lap per flush event)
var _fitLapSpecies as FitContributor.Field?;
var _fitLapFlushed as FitContributor.Field?;
var _fitLapBirdsDown as FitContributor.Field?;
var _fitLapShotResult as FitContributor.Field?;
var _fitLapLatitude as FitContributor.Field?;
var _fitLapLongitude as FitContributor.Field?;
```

Create these fields with `MESG_TYPE_LAP` in `startHuntActivity()`:

```
_fitLapSpecies = _session.createField(
    "flush_species", 3, FitContributor.DATA_TYPE_UINT8,
    {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "enum"}
);
// ... similar for fields 4-8
```

**Changes to ConfirmationView.mc:**

In `saveWaypoint()`, after saving to Object Store, add:

```
// Write per-flush data to FIT lap
var app = Application.getApp() as UplandHunterApp;
if (app._session != null && app._session.isRecording()) {
    // Set lap field values before creating the lap
    app._fitLapSpecies.setData(_species);
    app._fitLapFlushed.setData(_quantityFlushed);
    app._fitLapBirdsDown.setData(_birdsDown);
    app._fitLapShotResult.setData(_shotResult);
    app._fitLapLatitude.setData((_capturedLat * 1e7).toNumber());
    app._fitLapLongitude.setData((_capturedLon * 1e7).toNumber());
    app._session.addLap();
}
```

**Estimated effort:** 50-80 lines of Monkey C. Low risk — addLap() is well-documented in Connect IQ SDK.

#### Phase 2: Add Communications.makeWebRequest()

**New file:** `source/Utils/CoveySync.mc`

**New manifest permission:**
```xml
<iq:uses-permission id="Communications"/>
```

**Functionality:**
- Serialize all session waypoints with `birdsDown > 0` into a dictionary
- POST to the Supabase Edge Function URL (configurable via app settings)
- Handle success/failure callbacks
- Store "last synced" timestamp to avoid re-sending

**Changes to PostHuntSummaryView.mc:**
- Add a "Sync to Covey" option on the post-hunt summary screen
- Show sync status (pending, success, failed)
- Retry on failure

**Estimated effort:** 150-250 lines of Monkey C. Medium risk — requires managing auth tokens and handling network failures gracefully.

**Auth approach for Phase 2:**
The watch app needs to authenticate with CoveyTracker's Supabase. Options:
1. **Pre-shared API key** stored in watch app settings (configurable via Garmin Connect Mobile). The Edge Function validates this key. Simple but the key is stored in plaintext on the watch.
2. **Service-role scoped token** — a dedicated Supabase API key with narrow permissions (insert to harvest_entries only). Generated once, stored in watch settings.
3. **One-time pairing flow** — user enters a short code from CoveyTracker into the watch app, which exchanges it for a long-lived token. More secure, more complex.

**Recommendation for Phase 2:** Option 2 (scoped API key in settings). Since this is a single-user personal app that will never be on the Connect IQ store, the security constraints are low. The key is set once via Garmin Connect Mobile app settings.

---

### 8.2 CoveyTracker Changes (React + Supabase)

#### New Database Objects

**Migration: `20260327000001_hunt_imports.sql`**

```sql
-- Hunt imports table — tracks imported hunts for idempotency
CREATE TABLE IF NOT EXISTS hunt_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  source text NOT NULL CHECK (source IN ('fit_upload', 'manual', 'watch_direct')),
  hunt_date date NOT NULL,
  state_id uuid NOT NULL REFERENCES states(id),
  entries_created integer NOT NULL DEFAULT 0,
  result_data jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, idempotency_key)
);

ALTER TABLE hunt_imports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "hunt_imports_all" ON hunt_imports
  FOR ALL TO authenticated USING (auth.uid() = user_id);
```

**Species table updates:**

```sql
-- Add granular grouse species and mapping column
ALTER TABLE species ADD COLUMN IF NOT EXISTS
  upland_hunter_enum integer UNIQUE;

-- Update existing species with enum mappings
UPDATE species SET upland_hunter_enum = 0 WHERE name = 'Pheasant';
UPDATE species SET upland_hunter_enum = 1 WHERE name = 'Quail';
UPDATE species SET upland_hunter_enum = 2 WHERE name = 'Chukar';
UPDATE species SET upland_hunter_enum = 6 WHERE name = 'Woodcock';
UPDATE species SET upland_hunter_enum = 7 WHERE name = 'Prairie Chicken';
UPDATE species SET upland_hunter_enum = 8 WHERE name = 'Partridge';
UPDATE species SET upland_hunter_enum = 9 WHERE name = 'Dove';

-- Add missing species for UplandHunter parity
INSERT INTO species (name, upland_hunter_enum) VALUES
  ('Ruffed Grouse', 3),
  ('Sage Grouse', 4)
ON CONFLICT (name) DO NOTHING;

-- Map Sharp-tailed Grouse
UPDATE species SET upland_hunter_enum = 5 WHERE name = 'Sharp-tailed Grouse';

-- Rename generic "Grouse" if it conflicts
-- (depends on whether existing regulations reference it)
```

**Optional: Add GPS coordinates to harvest_entries:**

```sql
ALTER TABLE harvest_entries ADD COLUMN IF NOT EXISTS
  latitude double precision;
ALTER TABLE harvest_entries ADD COLUMN IF NOT EXISTS
  longitude double precision;
ALTER TABLE harvest_entries ADD COLUMN IF NOT EXISTS
  import_id uuid REFERENCES hunt_imports(id);
```

#### New Supabase Edge Function

**File:** `supabase/functions/import-hunt/index.ts`

Implements the logic described in Section 7.3. Key dependencies:
- `@supabase/supabase-js` for database access
- Request body validation
- Idempotency check
- Compliance validation loop
- Transactional insert

#### New Frontend Pages and Components

| File | Purpose |
|---|---|
| `src/pages/ImportHunt.tsx` | Main import page — FIT upload, review, confirm |
| `src/components/import/FitUploader.tsx` | Drag-and-drop FIT file upload with client-side parsing |
| `src/components/import/FlushReviewTable.tsx` | Table showing parsed flushes, species mapping, state selection |
| `src/components/import/ImportConfirmation.tsx` | Post-import summary with compliance results |
| `src/lib/fit-parser.ts` | FIT binary file parser wrapper (wraps `fit-file-parser` npm package) |
| `src/lib/species-mapping.ts` | UplandHunter enum to CoveyTracker species_id mapping |

**Import flow UI wireframe:**

```
+--------------------------------------------+
|  Import Hunt from UplandHunter             |
+--------------------------------------------+
|                                            |
|  [Drop .FIT file here or click to browse]  |
|                                            |
|  -- or --                                  |
|                                            |
|  [Enter manually from watch summary]       |
|                                            |
+--------------------------------------------+

    (after FIT upload and parsing)

+--------------------------------------------+
|  Hunt Summary — Nov 15, 2026               |
|  Duration: 4h 23m | Distance: 6.2 mi      |
+--------------------------------------------+
|  State: [Kansas          v]  (auto-detected |
|          from GPS)                          |
+--------------------------------------------+
|  Species       | Flushed | Downed | Import |
|  ------------- | ------- | ------ | ------ |
|  Pheasant      |    4    |   2    |  [x]   |
|  Quail         |   20    |   2    |  [x]   |
|  Grouse (Sage) |    1    |   0    |  [ ]   |
+--------------------------------------------+
|  Note: Only species with birds downed will  |
|  create harvest entries. 0-downed species   |
|  are shown but unchecked.                   |
+--------------------------------------------+
|                                            |
|  [Import 2 Entries]        [Cancel]        |
|                                            |
+--------------------------------------------+
```

**Route addition in App.tsx:**

```tsx
<Route path="/import" element={<ImportHunt />} />
```

**Navigation update in Sidebar/BottomNav:**

Add "Import" link with an upload icon.

---

### 8.3 Infrastructure Changes

#### Phase 1 — No new infrastructure

- FIT parsing happens client-side in the browser
- Import logic runs as a Supabase Edge Function (already part of the Supabase plan)
- No new services, no new domains, no new API keys

#### Phase 2 — Supabase Edge Function for watch-direct POST

- Same Edge Function as Phase 1, accepting `source: 'watch_direct'`
- Supabase Edge Functions are included in the free tier
- No CORS issues — the watch POSTs directly via `makeWebRequest()`, which is not browser-constrained
- Need to configure the Edge Function URL in UplandHunter's app settings (stored in Garmin Connect Mobile)

#### NPM Dependencies for CoveyTracker

```
npm install fit-file-parser    # FIT binary format parser
```

No other new dependencies. The existing Supabase client handles all API communication.

---

## 9. Architecture Decision Records

### ADR-001: Per-Flush FIT Lap Records as Primary Data Transport

**Status:** Proposed

**Context:**
UplandHunter records detailed per-flush data (species, quantity, GPS, shot result) in the Garmin Object Store, but this data is only accessible on the watch. The FIT file that syncs to Garmin Connect currently contains only session-level aggregates (total flushes, total birds down). CoveyTracker needs per-species data to enforce state-specific daily and possession limits.

**Decision:**
Add per-flush lap records to the FIT file using `ActivityRecording.Session.addLap()` with custom `FitContributor.Field` entries at the `MESG_TYPE_LAP` level. Each flush event creates a FIT lap containing species, quantity flushed, birds down, shot result, and GPS coordinates.

**Consequences:**
- FIT files now contain full hunt detail, making them a reliable data transport mechanism
- CoveyTracker can parse the FIT file client-side without any server-side processing for the parsing step
- FIT files remain compatible with Garmin Connect (extra fields are simply "developer fields" that Garmin ignores)
- Slight increase in Monkey C code complexity (50-80 lines)
- FIT file size increases negligibly (~100 bytes per flush)
- This approach works offline — no internet required during the hunt

---

### ADR-002: Client-Side FIT Parsing Over Server-Side Processing

**Status:** Proposed

**Context:**
FIT files uploaded to CoveyTracker need to be parsed to extract flush data. This parsing could happen client-side (in the browser) or server-side (in a Supabase Edge Function or Cloudflare Worker).

**Decision:**
Parse FIT files client-side in the browser using the `fit-file-parser` npm package. The parsed data is displayed for user review before being sent to the Supabase Edge Function for compliance validation and storage.

**Consequences:**
- No server compute cost for parsing — free at any scale
- User can review and correct data before it hits the database
- Faster feedback loop — no round-trip to server for parsing
- The FIT file never leaves the user's device (privacy, consistent with CoveyTracker's client-side philosophy)
- Depends on a third-party npm package for FIT parsing — risk of abandonment, but FIT format is stable
- Cannot enforce server-side validation of the FIT file contents (the server trusts the client's parsed output). Acceptable for a single-user app.

---

### ADR-003: Supabase Edge Function Over Cloudflare Worker for Import API

**Status:** Proposed

**Context:**
The import endpoint needs to validate compliance, insert harvest entries, and check idempotency. Both Supabase Edge Functions and Cloudflare Workers could host this logic.

**Decision:**
Use a Supabase Edge Function.

**Consequences:**
- Single infrastructure provider (Supabase) for auth, database, and serverless functions
- Direct database access without managing connection strings or secrets in a separate platform
- Can call existing Postgres functions (validate_harvest_entry) directly
- Simpler deployment: `supabase functions deploy import-hunt`
- Supabase Edge Functions use Deno runtime (TypeScript), which differs from CoveyTracker's Vite/Node toolchain — minor friction
- Free tier includes 500K function invocations/month — more than sufficient for a single user

---

### ADR-004: Deferred Garmin API Integration

**Status:** Proposed

**Context:**
Garmin offers a Health API that could push new activities to a webhook automatically, eliminating the manual FIT file download. However, this API requires business developer partnership approval and an OAuth implementation.

**Decision:**
Defer Garmin Health API integration. Use manual FIT download/upload for Phase 1 and watch-direct Communications API for Phase 2.

**Consequences:**
- No dependency on Garmin's API approval timeline or policies
- No OAuth flow to implement and maintain
- Slightly worse UX (manual download step) compensated by being available immediately
- If Garmin API access is eventually granted, the Edge Function architecture supports adding a webhook endpoint with minimal changes
- The Phase 2 Communications API path provides near-equivalent automation without Garmin API approval

---

### ADR-005: All-or-Nothing Import Semantics

**Status:** Proposed

**Context:**
When importing a multi-species hunt, some species may pass compliance while others are blocked (e.g., pheasant daily limit already reached, but quail is fine). Should the import save the passing entries and reject only the blocked ones?

**Decision:**
Reject the entire import if any entry fails compliance. Return all compliance results so the user can adjust quantities or remove species before retrying.

**Consequences:**
- Simpler mental model: an import either fully succeeds or fully fails
- Prevents partial hunt records that could confuse the compliance math later
- User sees all compliance issues at once and can fix them before retrying
- Slightly worse UX if only one species is blocked — user must remove it and re-import. Mitigated by showing exactly which species failed and why.
- Alternative considered: partial import with a "fix these later" workflow. Rejected because partial state makes possession calculations ambiguous.

---

## 10. Implementation Sequence

### Week 1: UplandHunter FIT Lap Records

1. Add lap-level FitContributor fields to `UplandHunterApp.mc`
2. Add `addLap()` call to `ConfirmationView.mc` after waypoint save
3. Test in simulator: verify FIT file contains lap records with custom fields
4. Test with real device: complete a hunt, sync to Garmin Connect, download FIT, verify fields present
5. Update `CLAUDE.md` and `BUILD_LOG.md`

### Week 2: CoveyTracker Import UI

1. Install `fit-file-parser` npm package
2. Create `src/lib/fit-parser.ts` — wrapper for FIT parsing with type definitions
3. Create `src/lib/species-mapping.ts` — enum-to-UUID mapping utilities
4. Create `src/pages/ImportHunt.tsx` — file upload, parse, review, submit
5. Add route and navigation link
6. Test with FIT files from Week 1

### Week 3: Supabase Backend

1. Create migration: `hunt_imports` table, species `upland_hunter_enum` column, new species rows
2. Create Edge Function: `import-hunt` with validation, compliance checks, idempotency
3. Wire ImportHunt page to Edge Function
4. End-to-end test: hunt on watch -> sync -> download FIT -> upload to CoveyTracker -> harvest entries created -> compliance verified
5. Deploy to production (covey.zachmartens.com)

### Week 4+ (Phase 2, Optional): Watch-Direct Sync

1. Add `Communications` permission to UplandHunter manifest
2. Create `CoveySync.mc` with `makeWebRequest()` POST logic
3. Add sync trigger to `PostHuntSummaryView.mc`
4. Add API key setting for watch app configuration
5. Update Edge Function to accept `source: 'watch_direct'`
6. Field test with actual hunt

---

## Appendix A: FIT File Format Reference

The FIT (Flexible and Interoperable Data Transfer) protocol is a binary format defined by Garmin/ANT+. Key concepts for this integration:

- **Messages:** Records within the file. Types include Session (one per activity), Lap (one per lap/flush), Record (one per GPS sample).
- **Developer Fields:** Custom fields added by Connect IQ apps. Identified by developer data index + field definition number.
- **Lap records:** Created by `addLap()`. Each lap spans from the end of the previous lap to the current point. Custom fields attached to lap records appear in the lap's developer fields.

**FIT file structure after enhancement:**

```
FILE_HEADER
  FILE_ID
  DEVICE_INFO
  SESSION
    developer_field: total_flushes = 3
    developer_field: total_birds_down = 2
    developer_field: shots_taken = 3
  LAP [0] (flush #1)
    developer_field: flush_species = 0 (Pheasant)
    developer_field: flush_flushed = 2
    developer_field: flush_birds_down = 1
    developer_field: flush_shot_result = 0 (HIT)
    developer_field: flush_latitude = 389456000 (38.9456 * 1e7)
    developer_field: flush_longitude = -985432000 (-98.5432 * 1e7)
    standard: start_time, total_elapsed_time, start_position_lat/long
  LAP [1] (flush #2)
    developer_field: flush_species = 1 (Quail)
    developer_field: flush_flushed = 8
    developer_field: flush_birds_down = 0
    developer_field: flush_shot_result = 1 (MISSED)
    ...
  LAP [2] (flush #3)
    developer_field: flush_species = 0 (Pheasant)
    developer_field: flush_flushed = 1
    developer_field: flush_birds_down = 1
    developer_field: flush_shot_result = 0 (HIT)
    ...
  RECORD [0..N] (GPS trackpoints every 1-5 seconds)
    standard: timestamp, position_lat, position_long, altitude, heart_rate, ...
FILE_CRC
```

## Appendix B: fit-file-parser Usage Example

```typescript
import FitParser from 'fit-file-parser';

interface FlushLap {
  species: number;
  quantityFlushed: number;
  birdsDown: number;
  shotResult: number;
  latitude: number;
  longitude: number;
  timestamp: Date;
}

export function parseFitFile(buffer: ArrayBuffer): FlushLap[] {
  const parser = new FitParser({ force: true, mode: 'list' });
  const parsed = parser.parse(buffer);

  const flushes: FlushLap[] = [];

  for (const lap of parsed.laps ?? []) {
    // Developer fields from UplandHunter appear in the lap's developer_fields
    const devFields = lap.developer_fields ?? {};

    // Check if this lap has our custom flush data
    if (devFields.flush_species !== undefined) {
      flushes.push({
        species: devFields.flush_species,
        quantityFlushed: devFields.flush_flushed ?? 1,
        birdsDown: devFields.flush_birds_down ?? 0,
        shotResult: devFields.flush_shot_result ?? 2,
        latitude: (devFields.flush_latitude ?? 0) / 1e7,
        longitude: (devFields.flush_longitude ?? 0) / 1e7,
        timestamp: lap.start_time ?? lap.timestamp,
      });
    }
  }

  return flushes;
}
```

## Appendix C: Species Enum Alignment Plan

To eliminate mapping friction long-term, both systems should converge on the same species taxonomy:

| Enum | UplandHunter Name | CoveyTracker Name (Current) | CoveyTracker Name (Proposed) | Action |
|---|---|---|---|---|
| 0 | Pheasant | Pheasant | Pheasant | No change |
| 1 | Quail | Quail | Quail | No change |
| 2 | Chukar | Chukar | Chukar | No change |
| 3 | Grouse (Ruffed) | Grouse | Ruffed Grouse | Add new row |
| 4 | Grouse (Sage) | -- | Sage Grouse | Add new row |
| 5 | Grouse (Sharp-tail) | Sharp-tailed Grouse | Sharp-tailed Grouse | No change |
| 6 | Woodcock | Woodcock | Woodcock | No change |
| 7 | Prairie Chicken | Prairie Chicken | Prairie Chicken | No change |
| 8 | Partridge | Partridge | Partridge | No change |
| 9 | Dove | Dove | Dove | No change |
| 10 | Other | -- | Other | Add new row |
| -- | -- | Turkey | Turkey | Keep (no UplandHunter mapping) |
| -- | -- | Grouse (generic) | Grouse (generic) | Keep for backward compat |

After this alignment, existing CoveyTracker harvest entries referencing generic "Grouse" remain valid. New imports map to the specific grouse subspecies. Regulations can be defined at the subspecies level where states distinguish them.
