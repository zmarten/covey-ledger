import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

/**
 * PostHuntSummaryView — "Hunt Complete" wrapup screen shown after ending a hunt.
 *
 * Displayed when the hunter taps "End Hunt" from the main menu.
 * Shows a complete summary of the hunt before saving the FIT activity:
 *   - Duration and distance walked
 *   - Total flushes, shots taken, birds downed
 *   - Success rate (birds down / shots taken)
 *   - Per-species breakdown
 *
 * The activity is NOT stopped until the hunter dismisses this screen.
 * This ensures the final stats are written to the FIT file.
 *
 * SELECT or BACK on this screen stops the activity, saves the FIT file,
 * and returns to the main screen (which will show "Press SELECT to start").
 */
class PostHuntSummaryView extends WatchUi.View {

    // Computed stats — calculated once in onShow()
    var _totalFlushes as Number = 0;
    var _totalShots as Number = 0;
    var _totalDown as Number = 0;
    var _successRate as Number = 0;
    var _duration as Number = 0;
    var _distanceMiles as Double = 0.0d;

    // Per-species data — array of {species, flushed, downed} dictionaries.
    // Only species that appeared at least once are included.
    var _speciesBreakdown as Array?;

    // Scroll position for viewing the species breakdown section
    var _scrollOffset as Number = 0;

    /**
     * Constructor.
     */
    function initialize() {
        View.initialize();
    }

    /**
     * onShow() — Calculate all session stats from stored waypoints.
     *
     * We compute here (not in onUpdate) because loading waypoints from
     * Object Store is slow and should only happen once, not every redraw.
     */
    function onShow() as Void {
        var app = Application.getApp() as UplandHunterApp;
        var session = app.getHuntSession();

        // Load all waypoints recorded during this session
        var waypoints = WaypointManager.getSessionWaypoints(session.getStartTime());

        _totalFlushes = waypoints.size();
        _totalShots = 0;
        _totalDown = 0;

        // Per-species tracking arrays, indexed by species enum value
        var speciesFlushed = new [Constants.SPECIES_COUNT] as Array<Number>;
        var speciesDowned = new [Constants.SPECIES_COUNT] as Array<Number>;
        for (var i = 0; i < Constants.SPECIES_COUNT; i++) {
            speciesFlushed[i] = 0;
            speciesDowned[i] = 0;
        }

        for (var i = 0; i < waypoints.size(); i++) {
            var wp = waypoints[i];

            // HIT and MISSED both count as shots taken; NO_SHOT does not
            if (wp.shotResult == Constants.SHOT_HIT ||
                wp.shotResult == Constants.SHOT_MISSED) {
                _totalShots++;
            }
            _totalDown += wp.birdsDown;

            if (wp.species >= 0 && wp.species < Constants.SPECIES_COUNT) {
                speciesFlushed[wp.species] += wp.quantityFlushed;
                speciesDowned[wp.species] += wp.birdsDown;
            }
        }

        // Success rate = birds downed / shots taken (avoid divide-by-zero)
        if (_totalShots > 0) {
            _successRate = (_totalDown * 100) / _totalShots;
        } else {
            _successRate = 0;
        }

        _duration = session.getDuration();
        _distanceMiles = session.getDistanceMiles();

        // Build species breakdown, skipping any species not encountered
        _speciesBreakdown = [] as Array;
        for (var i = 0; i < Constants.SPECIES_COUNT; i++) {
            if (speciesFlushed[i] > 0) {
                _speciesBreakdown.add({
                    "species" => i,
                    "flushed" => speciesFlushed[i],
                    "downed" => speciesDowned[i]
                });
            }
        }
    }

    /**
     * onUpdate() — Draw the post-hunt summary screen.
     *
     * Layout (scrollable):
     *   HUNT COMPLETE
     *   ─────────────
     *   Duration       2h 15m
     *   Distance       4.2 mi
     *   Flushes        7
     *   Shots          5
     *   Birds Down     3
     *   Success        60%
     *   ─ By Species ─
     *   Pheasant       4 / 2
     *   Quail          3 / 1
     *   ─────────────
     *   SELECT to save
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // ── Header ──
        dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 22, Graphics.FONT_SMALL,
            "HUNT COMPLETE", Graphics.TEXT_JUSTIFY_CENTER);

        // Thin divider line under header
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(60, 48, screenW - 60, 48);

        // All stat rows scroll vertically. Row height = 33px.
        var y = 56 - (_scrollOffset * 33);
        var rowH = 33;
        var leftX = 50;
        var rightX = screenW - 50;

        // Helper: only draw rows that are visible on screen
        // ── Duration ──
        if (y > 45 && y < screenH - 25) {
            drawStatRow(dc, leftX, rightX, y, "Duration", formatDuration(_duration));
        }
        y += rowH;

        // ── Distance ──
        if (y > 45 && y < screenH - 25) {
            drawStatRow(dc, leftX, rightX, y, "Distance",
                Constants.formatStatDistance(_distanceMiles));
        }
        y += rowH;

        // ── Flushes ──
        if (y > 45 && y < screenH - 25) {
            drawStatRow(dc, leftX, rightX, y, "Flushes",
                _totalFlushes.format("%d"));
        }
        y += rowH;

        // ── Shots ──
        if (y > 45 && y < screenH - 25) {
            drawStatRow(dc, leftX, rightX, y, "Shots",
                _totalShots.format("%d"));
        }
        y += rowH;

        // ── Birds Down ──
        if (y > 45 && y < screenH - 25) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftX, y, Graphics.FONT_XTINY,
                "Birds Down", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, y, Graphics.FONT_SMALL,
                _totalDown.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowH;

        // ── Success Rate ──
        if (y > 45 && y < screenH - 25) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftX, y, Graphics.FONT_XTINY,
                "Success", Graphics.TEXT_JUSTIFY_LEFT);

            var rateColor = Constants.COLOR_ALERT;
            if (_successRate >= 50) { rateColor = Constants.COLOR_SUCCESS; }
            else if (_successRate >= 25) { rateColor = Constants.COLOR_WARNING; }
            dc.setColor(rateColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, y, Graphics.FONT_SMALL,
                _successRate.format("%d") + "%", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowH + 5;

        // ── Species breakdown ──
        if (_speciesBreakdown != null && _speciesBreakdown.size() > 0) {
            if (y > 45 && y < screenH - 25) {
                dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, y, Graphics.FONT_XTINY,
                    "- By Species -", Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += 24;

            for (var i = 0; i < _speciesBreakdown.size(); i++) {
                if (y > 45 && y < screenH - 25) {
                    var entry = _speciesBreakdown[i] as Dictionary;
                    var name = Constants.getSpeciesName(entry["species"] as Number);
                    var fl = (entry["flushed"] as Number).format("%d");
                    var dn = (entry["downed"] as Number).format("%d");

                    dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(leftX, y, Graphics.FONT_XTINY,
                        name, Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(rightX, y, Graphics.FONT_XTINY,
                        fl + "/" + dn, Graphics.TEXT_JUSTIFY_RIGHT);
                }
                y += 26;
            }
        }

        // If no flushes at all, show a message instead of the blank breakdown section
        if (_totalFlushes == 0) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, screenH / 2 + 20, Graphics.FONT_XTINY,
                "No flushes recorded", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Bottom hint ──
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 28, Graphics.FONT_XTINY,
            "SELECT: Save & Exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * drawStatRow() — Renders a label/value pair in the standard two-column layout.
     *
     * @param leftX  — x position for the left-aligned label
     * @param rightX — x position for the right-aligned value
     * @param y      — vertical position
     * @param label  — the left-side label string
     * @param value  — the right-side value string (drawn in white)
     */
    function drawStatRow(dc as Graphics.Dc, leftX as Number, rightX as Number,
                          y as Number, label as String, value as String) as Void {
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, y, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    /**
     * formatDuration() — Converts seconds to "Xh Ym" string for display.
     *
     * @param seconds — total hunt duration in seconds
     * @return formatted string like "2h 15m" or "0h 45m"
     */
    function formatDuration(seconds as Number) as String {
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        return hours.format("%d") + "h " + minutes.format("%d") + "m";
    }
}

/**
 * PostHuntSummaryDelegate — Input handler for the post-hunt summary screen.
 *
 * SELECT or BACK both save and exit — there's nothing to cancel at this point.
 * UP/DOWN scroll the stats if there are many species in the breakdown.
 */
class PostHuntSummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    /**
     * onSelect() — Save the hunt activity and return to the main screen.
     *
     * Stops and saves the FIT activity recording, then pops back to
     * MainView. The FIT file will sync to Garmin Connect on the next
     * phone connection.
     */
    function onSelect() as Boolean {
        saveAndExit();
        return true;
    }

    /**
     * onBack() — Also saves and exits.
     *
     * There's no "cancel" for ending a hunt — the data is already recorded.
     */
    function onBack() as Boolean {
        saveAndExit();
        return true;
    }

    /**
     * onNextPage() — Scroll down to see the species breakdown.
     */
    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as PostHuntSummaryView;
        view._scrollOffset++;
        WatchUi.requestUpdate();
        return true;
    }

    /**
     * onPreviousPage() — Scroll back up.
     */
    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as PostHuntSummaryView;
        if (view._scrollOffset > 0) {
            view._scrollOffset--;
            WatchUi.requestUpdate();
        }
        return true;
    }

    /**
     * saveAndExit() — Stop the hunt activity and return to MainView.
     *
     * Called by both SELECT and BACK so the hunter can't accidentally
     * lose their data by pressing the wrong button.
     */
    function saveAndExit() as Void {
        var app = Application.getApp() as UplandHunterApp;
        // Stop and save the FIT activity file
        app.stopHuntActivity();
        // Return to MainView
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
