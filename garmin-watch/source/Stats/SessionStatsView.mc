import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

/**
 * SessionStatsView — Displays hunting statistics for the current session.
 *
 * Shows a scrollable summary of the current hunt:
 *   - Total flushes (how many times birds flushed)
 *   - Shots taken (times the hunter fired)
 *   - Success rate (birds downed / shots taken, as %)
 *   - Total birds downed
 *   - Species breakdown (each species with flush/down counts)
 *   - Hunt duration
 *   - Distance covered
 *
 * Data is calculated from stored waypoints via WaypointManager.
 * Only waypoints from the current session are included.
 */
class SessionStatsView extends WatchUi.View {

    // Computed stats — calculated once in onShow(), not on every redraw
    var _totalFlushes as Number = 0;
    var _totalShots as Number = 0;
    var _totalDown as Number = 0;
    var _successRate as Number = 0;   // Percentage (0-100)
    var _duration as Number = 0;       // Seconds
    var _distanceMiles as Double = 0.0d;

    // Species breakdown: array of {species, flushed, downed} dictionaries
    var _speciesBreakdown as Array?;

    // Scroll offset for viewing more stats than fit on screen
    var _scrollOffset as Number = 0;

    /**
     * Constructor.
     */
    function initialize() {
        View.initialize();
    }

    /**
     * onShow() — Calculate all stats from stored waypoints.
     *
     * We compute everything here (not in onUpdate) because:
     * 1. Stats don't change while viewing them
     * 2. Loading waypoints from storage is slow
     * 3. Computing once is more efficient than computing every redraw
     */
    function onShow() as Void {
        var app = Application.getApp() as UplandHunterApp;
        var session = app.getHuntSession();

        // Get all waypoints from this session
        var waypoints = WaypointManager.getSessionWaypoints(session.getStartTime());

        // Calculate totals
        _totalFlushes = waypoints.size();
        _totalShots = 0;
        _totalDown = 0;

        // Species tracking — use an array indexed by species enum
        var speciesFlushed = new [Constants.SPECIES_COUNT] as Array<Number>;
        var speciesDowned = new [Constants.SPECIES_COUNT] as Array<Number>;
        for (var i = 0; i < Constants.SPECIES_COUNT; i++) {
            speciesFlushed[i] = 0;
            speciesDowned[i] = 0;
        }

        // Iterate through all session waypoints to compute stats
        for (var i = 0; i < waypoints.size(); i++) {
            var wp = waypoints[i];

            // Count shots (only HIT and MISSED count as shots taken)
            if (wp.shotResult == Constants.SHOT_HIT ||
                wp.shotResult == Constants.SHOT_MISSED) {
                _totalShots++;
            }

            // Count birds downed
            _totalDown += wp.birdsDown;

            // Track per-species counts
            if (wp.species >= 0 && wp.species < Constants.SPECIES_COUNT) {
                speciesFlushed[wp.species] += wp.quantityFlushed;
                speciesDowned[wp.species] += wp.birdsDown;
            }
        }

        // Calculate success rate (avoid division by zero)
        if (_totalShots > 0) {
            _successRate = (_totalDown * 100) / _totalShots;
        } else {
            _successRate = 0;
        }

        // Get duration and distance from the hunt session
        _duration = session.getDuration();
        _distanceMiles = session.getDistanceMiles();

        // Build species breakdown — only include species that were actually seen
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
     * onUpdate() — Draw the stats screen.
     *
     * Shows stats in a vertically scrollable layout.
     * Scroll with UP/DOWN buttons to see species breakdown.
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // Header
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 25, Graphics.FONT_SMALL,
            "SESSION STATS", Graphics.TEXT_JUSTIFY_CENTER);

        // All stats are positioned relative to scroll offset.
        // Each stat row is ~35px tall.
        var y = 65 - (_scrollOffset * 35);
        var rowHeight = 35;
        var leftPad = 50;
        var rightPad = screenW - 50;

        // --- Total Flushes ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Total Flushes", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                _totalFlushes.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight;

        // --- Shots Taken ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Shots Taken", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                _totalShots.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight;

        // --- Success Rate ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Success Rate", Graphics.TEXT_JUSTIFY_LEFT);

            // Color code the success rate
            var rateColor = Constants.COLOR_ALERT; // Red for low rate
            if (_successRate >= 50) {
                rateColor = Constants.COLOR_SUCCESS;  // Green for high rate
            } else if (_successRate >= 25) {
                rateColor = Constants.COLOR_WARNING;  // Yellow for medium
            }
            dc.setColor(rateColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                _successRate.format("%d") + "%", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight;

        // --- Birds Downed ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Birds Downed", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                _totalDown.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight;

        // --- Hunt Duration ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Hunt Time", Graphics.TEXT_JUSTIFY_LEFT);

            var hours = _duration / 3600;
            var minutes = (_duration % 3600) / 60;
            var timeStr = hours.format("%d") + "h " + minutes.format("%d") + "m";
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight;

        // --- Distance ---
        if (y > 40 && y < screenH - 30) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                "Distance", Graphics.TEXT_JUSTIFY_LEFT);
            // Uses Constants.formatStatDistance() to show mi or km based on settings
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightPad, y, Graphics.FONT_SMALL,
                Constants.formatStatDistance(_distanceMiles), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += rowHeight + 10;

        // --- Species Breakdown ---
        if (_speciesBreakdown != null && _speciesBreakdown.size() > 0) {
            if (y > 40 && y < screenH - 30) {
                dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, y, Graphics.FONT_XTINY,
                    "— By Species —", Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += 25;

            for (var i = 0; i < _speciesBreakdown.size(); i++) {
                if (y > 40 && y < screenH - 30) {
                    var entry = _speciesBreakdown[i] as Dictionary;
                    var name = Constants.getSpeciesName(entry["species"] as Number);
                    var flushed = entry["flushed"] as Number;
                    var downed = entry["downed"] as Number;

                    dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(leftPad, y, Graphics.FONT_XTINY,
                        name, Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(rightPad, y, Graphics.FONT_XTINY,
                        flushed.format("%d") + "/" + downed.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
                }
                y += 25;
            }
        }

        // No data message
        if (_totalFlushes == 0) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, screenH / 2, Graphics.FONT_SMALL,
                "No flushes yet", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Scroll indicator
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 30, Graphics.FONT_XTINY,
            "BACK to return", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

/**
 * SessionStatsDelegate — Input handler for the stats screen.
 * UP/DOWN scrolls, BACK returns to main view.
 */
class SessionStatsDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as SessionStatsView;
        view._scrollOffset++;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as SessionStatsView;
        if (view._scrollOffset > 0) {
            view._scrollOffset--;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
