# Upland Hunter Hardware Validation Plan

## Goal

Validate the real ANT+ dog-tracker path on actual hardware and capture enough evidence to either confirm the current reverse-engineered packet format or correct it quickly.

Primary code under test:
- `source/DogTracker/DogTrackerSensor.mc`
- `source/MapView/HuntMapView.mc`
- `source/MainView.mc`

## Test Setup

Required hardware:
- Garmin watch running this build
- Garmin Alpha or Astro handheld
- At least one active dog collar paired to the handheld

Required handheld settings:
- Enable `Broadcast Dog Data`
- Keep the handheld within normal ANT range of the watch during testing

Recommended environment:
- Start outside with GPS lock on both watch and handheld
- Use one dog first, then repeat with multiple dogs

## What To Watch In Logs

The app now logs a few raw ANT payload samples per page plus state transitions. Look for lines like:
- `DogTrackerSensor: Sample page 1 payload=...`
- `DogTrackerSensor: Sample page 2 payload=...`
- `DogTrackerSensor: Sample page 3 payload=...`
- `DogTrackerSensor: Dog #0 status MOVING -> ON_POINT (...)`
- `DogTrackerSensor: Dog #0 name=Rex`

These logs should answer:
- Which page IDs are actually broadcast
- Whether page `1/2/3` assumptions are correct
- Whether distance/bearing/status bytes decode sensibly
- Whether battery and color bytes look plausible

## Validation Sequence

1. Launch the app and start a hunt.
2. Confirm the main screen changes from searching to connected.
3. Verify the watch logs a paired device number and at least one sample payload.
4. Confirm one dog appears on the main screen with a sensible name, distance, and direction.
5. Open the map view and confirm the same dog appears there.
6. Move the dog and verify distance and direction change plausibly.
7. Force an `on point` condition and confirm:
   - Main view highlights the dog
   - Haptic alert fires
   - Logs show a status transition with the raw status byte
8. If available, force other conditions:
   - stationary
   - treed
   - collar GPS lost
   - communication lost
9. Repeat with 2-3 dogs to confirm indexing and name assignment stay stable.
10. End the hunt and verify the app closes the channel cleanly.

## Pass Criteria

- Watch connects without crashing or hanging
- Main view and map view show the same dog set
- Names are readable and stable
- Distance changes roughly match the handheld
- Bearing updates are directionally correct
- Point alerts map to the right dog and feel timely
- Raw page logs are consistent enough to document the protocol

## Failure Signals To Capture

- No payload samples logged after connection
- Unknown page IDs appear frequently
- Dog names are garbled or truncated incorrectly
- Distances are obviously wrong by large factors
- Bearings jump wildly or are mirrored
- Status transitions do not match what the handheld shows
- Map shows no dogs while main view does
- Search timeout loops forever even with handheld nearby

## Questions This Test Should Resolve

- Are page IDs `1`, `2`, and `3` correct?
- Is distance truly little-endian meters in bytes `2-3`?
- Is bearing truly little-endian tenths of degrees in bytes `4-5`?
- What raw status byte values correspond to point, treed, GPS lost, and comm lost?
- Is byte `7` signal quality, battery, or something else on page `1`?
- Is the System 8 pairing flow usable as-is, or does the stub need real scan support before field use?

## Follow-Up After First Hardware Session

- Update `DogTrackerSensor.mc` constants and byte mappings using captured logs
- Update `ISSUES.md` with confirmed protocol details
- Decide whether to persist the paired device number
- Decide whether the pairing delegate needs full native scan support immediately or can remain a later milestone
