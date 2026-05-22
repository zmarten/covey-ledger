# Upland Hunter — Known Issues & TODOs

## Critical (Must Fix Before Field Use)

_None — Phase 1 compiles clean._

## High Priority
- [ ] **ANT+ dog tracker protocol needs real hardware validation** — App now uses DogTrackerSensor (real ANT+) instead of DogTrackerMock. The handheld must have "Broadcast Dog Data" enabled. — DogTrackerSensor.mc has best-effort packet parsing based on community reverse engineering. Page IDs (1=data, 2=name, 3=color), byte layouts (distance/bearing/status), and status byte values are estimated. Must test with real Alpha/Astro handheld with "Broadcast Dog Data" enabled. Channel config (device type 0, frequency 57, period 4096) may need tuning. Reference: ekutter's Dog Tracker app (https://ekutter.github.io).
- [ ] **SensorDelegate pairing flow needs System 8 testing** — DogTrackerPairingDelegate now performs a best-effort ANT wildcard scan, reports discovered devices to the native pairing UI, and persists the selected ANT device number for reconnects. Full System 8 validation is still required to confirm the native UI accepts the discovered `SensorInfo` objects and that the stored device number is reused as expected on subsequent hunts.
- [x] ~~**ConfirmationView popToMainView timing**~~ — Fixed: PopChainHelper class now accepts an exact depth count (4 or 5 depending on whether BirdsDown was shown). Pops exactly the right number of times with 50ms timer delays between each.

## Medium Priority

- [ ] **Launcher icon is placeholder** — Current icon is a plain 40x40 orange square. Need a proper upland hunting icon for store submission.
- [ ] **MRU species sorting not implemented** — SpeciesSelectView shows species in static default order. Need to track usage counts in Object Store and sort by most-recently-used.
- [ ] **QuantityView covey size selector** — UI shows covey size but there's no input method to change it. Need to add a sub-menu or toggle for covey sizes (8, 12, 16, 20, 25).

## Low Priority / Nice to Have

- [x] ~~**High contrast mode** — Setting exists but views don't read it yet.~~ — Phase 5: All views now use `Constants.getBgColor()`/`getTextColor()` helpers. Pure black background in high contrast mode.
- [x] ~~**GPS poll rate setting** — Property exists but not wired.~~ — Phase 5: GPS throttling in `onPosition()` respects gpsPollRate setting (5s/2s/1s).

## Technical Debt

- [ ] **Unit tests not written** — Need CoordinateMathTest.mc, WaypointManagerTest.mc, FlushWorkflowTest.mc per project structure spec.
- [ ] **Menu2 uses XML resource** — menus.xml defines a static menu but MainDelegate builds the menu dynamically in code. The XML menu definition is unused — could remove it or switch to using it.

## Open Questions

- [ ] Confirm exact ANT+ packet structure for Alpha/Astro dog data broadcast (see DogTrackerSensor.mc comments for current best-effort layout)
- [ ] Verify FIT file custom field support for waypoint data (species, shot result)
- [ ] Test memory limits on Fenix 8 Solar — what's the practical ceiling for waypoint count?
- [ ] Determine optimal GPS polling frequency (balance accuracy vs. battery)
- [ ] Confirm physical button mappings available on Fenix 8 Solar for custom app assignment
- [x] ~~Research if Garmin Map API supports offline topo tiles on Fenix 8~~ — Yes, MapTrackView renders device maps (Phase 3 complete)
- [ ] Check if System 8 Notifications API can alert for dog-on-point when app is backgrounded
