import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

/**
 * ConfirmationView — Screen 5 of 5 in the Mark Flush workflow.
 *
 * Shows a summary of the recorded flush:
 *   - Species, quantity, shot result, birds downed
 *   - GPS coordinates and timestamp
 *   - "Flush Saved!" confirmation message
 *
 * Auto-dismisses after 2 seconds and returns to the main screen.
 * Also triggers a haptic confirmation buzz so the hunter knows the
 * data was saved without needing to look at the watch.
 *
 * This screen also saves the waypoint data to persistent storage
 * via the WaypointManager (Phase 1.5).
 *
 * FLOW: SpeciesSelect → Quantity → ShotResult → BirdsDown → [Confirmation]
 */
class ConfirmationView extends WatchUi.View {

    // All the data collected during the flush workflow
    var _species as Number;
    var _quantityFlushed as Number;
    var _coveySize as Number?;
    var _shotResult as Number;
    var _birdsDown as Number;
    var _capturedLat as Double;
    var _capturedLon as Double;
    var _capturedTime as Number;

    // How many views to pop when returning to MainView.
    // Passed in by the caller who knows how deep the workflow stack is:
    //   4 = Species + Quantity + ShotResult + Confirmation (no BirdsDown)
    //   5 = Species + Quantity + ShotResult + BirdsDown + Confirmation
    var _workflowDepth as Number;

    // Manages the sequence of popView() calls to clear the workflow stack.
    // Stored here so it stays alive (via reference) during the pop sequence.
    var _popHelper as PopChainHelper?;

    // Timer for auto-dismiss after CONFIRMATION_TIMEOUT_MS
    var _dismissTimer as Timer.Timer?;

    /**
     * Constructor — receives the complete flush data and triggers save.
     *
     * @param workflowDepth — total number of workflow views on the stack
     *   including this one. Used to pop cleanly back to MainView:
     *   4 = no BirdsDown screen, 5 = BirdsDown screen was shown.
     */
    function initialize(species as Number, quantityFlushed as Number, coveySize as Number?,
                         shotResult as Number, birdsDown as Number,
                         lat as Double, lon as Double, time as Number,
                         workflowDepth as Number) {
        View.initialize();
        _species = species;
        _quantityFlushed = quantityFlushed;
        _coveySize = coveySize;
        _shotResult = shotResult;
        _birdsDown = birdsDown;
        _capturedLat = lat;
        _capturedLon = lon;
        _capturedTime = time;
        _workflowDepth = workflowDepth;
        _popHelper = null;

        // Save the waypoint to persistent storage.
        // This is done in the constructor so the data is saved immediately.
        // Even if the auto-dismiss timer fails or the app crashes, the data is safe.
        saveWaypoint();
    }

    /**
     * onShow() — Start the auto-dismiss timer and trigger haptic feedback.
     */
    function onShow() as Void {
        // Haptic confirmation buzz — the hunter feels this through their glove
        // and knows the flush was saved without looking at the screen.
        // Respects the hapticEnabled setting so users can disable vibrations.
        var hapticEnabled = Application.Properties.getValue("hapticEnabled");
        if (hapticEnabled != false && Attention has :vibrate) {
            var vibeProfile = [
                new Attention.VibeProfile(50, 200),  // Medium vibration, 200ms
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(vibeProfile);
        }

        // Start auto-dismiss timer
        _dismissTimer = new Timer.Timer();
        _dismissTimer.start(method(:onDismissTimer), Constants.CONFIRMATION_TIMEOUT_MS, false);
    }

    /**
     * onUpdate() — Draw the confirmation summary.
     *
     * Shows a clean summary of what was just recorded:
     *   ✓ Flush Saved!
     *   Pheasant x2
     *   SHOT — 1 down
     *   43.6532° N, -116.6735° W
     *   14:23:45
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // Success indicator — green checkmark area
        dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 40, Graphics.FONT_MEDIUM,
            "FLUSH SAVED!", Graphics.TEXT_JUSTIFY_CENTER);

        // Species and quantity
        var speciesText = Constants.getSpeciesName(_species);
        if (_quantityFlushed > 1) {
            speciesText = speciesText + " x" + _quantityFlushed.format("%d");
        }
        dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 90, Graphics.FONT_SMALL,
            speciesText, Graphics.TEXT_JUSTIFY_CENTER);

        // Shot result and birds downed
        var resultText = "";
        if (_shotResult == Constants.SHOT_HIT) {
            resultText = "SHOT - " + _birdsDown.format("%d") + " down";
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
        } else if (_shotResult == Constants.SHOT_MISSED) {
            resultText = "MISSED";
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        } else {
            resultText = "NO SHOT";
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(centerX, 125, Graphics.FONT_SMALL,
            resultText, Graphics.TEXT_JUSTIFY_CENTER);

        // Covey size if applicable
        if (_coveySize != null) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 155, Graphics.FONT_XTINY,
                "Covey: " + _coveySize.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // GPS coordinates
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        var latStr = _capturedLat.format("%.4f");
        var lonStr = _capturedLon.format("%.4f");
        dc.drawText(centerX, screenH - 100, Graphics.FONT_XTINY,
            latStr + ", " + lonStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Timestamp
        var now = Time.Gregorian.info(new Time.Moment(_capturedTime), Time.FORMAT_SHORT);
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d") + ":" + now.sec.format("%02d");
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 75, Graphics.FONT_XTINY,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Auto-dismiss hint
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 40, Graphics.FONT_XTINY,
            "Auto-dismiss in 2s...", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * onDismissTimer() — Called when the auto-dismiss timer fires.
     *
     * Pops ALL the flush workflow views off the stack to return
     * to the main hunt screen. We need to pop multiple times since
     * we pushed 4-5 views during the workflow.
     */
    function onDismissTimer() as Void {
        // Pop all flush workflow views to return to MainView.
        // popView() pops one view at a time. We need to pop back through
        // Confirmation → BirdsDown (if shown) → ShotResult → Quantity → Species → Main.
        // Using a loop to pop until we're back at the main view.
        popToMainView();
    }

    /**
     * popToMainView() — Pop all workflow views off the stack to return to MainView.
     *
     * Uses PopChainHelper to pop exactly _workflowDepth times with short
     * delays between each pop (required to avoid UI re-entrancy issues).
     * The helper instance is kept in _popHelper so it isn't GC'd during
     * the timer chain — it stays alive until the last pop completes.
     *
     * Always cancels the auto-dismiss timer first so that a manual dismiss
     * (SELECT/BACK) and the timer firing cannot both call this method —
     * the second call would pop views on whatever screen is shown next.
     */
    function popToMainView() as Void {
        if (_dismissTimer != null) {
            _dismissTimer.stop();
            _dismissTimer = null;
        }
        _popHelper = new PopChainHelper(_workflowDepth);
        _popHelper.startPopping();
    }

    /**
     * saveWaypoint() — Persist the flush data to Object Store.
     *
     * Creates a Waypoint object with all the collected data and saves
     * it via WaypointManager. This is the critical data persistence step —
     * once saved, the waypoint survives app restarts and watch reboots.
     */
    function saveWaypoint() as Void {
        // Wrap the entire save operation in a try/catch.
        // This is the MOST CRITICAL operation in the app — losing waypoint data
        // is unacceptable. Even if something goes wrong, we must not crash.
        try {
            // Create a Waypoint object from the collected data
            var waypoint = new Waypoint(
                _capturedLat, _capturedLon, _capturedTime,
                _species, _quantityFlushed, _birdsDown, _shotResult
            );

            // Set optional fields
            waypoint.coveySize = _coveySize;

            // Save to persistent storage via WaypointManager
            var saved = WaypointManager.saveWaypoint(waypoint);

            if (saved) {
                // Update FIT file data with new totals.
                // Load session waypoints to calculate accurate totals.
                var app = Application.getApp() as UplandHunterApp;
                var session = app.getHuntSession();
                var sessionWaypoints = WaypointManager.getSessionWaypoints(session.getStartTime());

                var totalFlushes = sessionWaypoints.size();
                var totalDown = 0;
                var totalShots = 0;
                for (var i = 0; i < sessionWaypoints.size(); i++) {
                    totalDown += sessionWaypoints[i].birdsDown;
                    if (sessionWaypoints[i].shotResult == Constants.SHOT_HIT ||
                        sessionWaypoints[i].shotResult == Constants.SHOT_MISSED) {
                        totalShots++;
                    }
                }

                app.updateFitData(totalFlushes, totalDown, totalShots);

                // Record a FIT lap for this individual flush so third-party apps
                // (CoveyTracker, Garmin Connect data fields) can see per-flush detail.
                // Called after updateFitData so the session-level totals are already current.
                app.recordFlushLap(_species, _quantityFlushed, _birdsDown, _shotResult,
                                   _capturedLat, _capturedLon);
            } else {
                System.println("WARNING: Failed to save waypoint!");
            }
        } catch (ex) {
            // If anything goes wrong during save, log it but don't crash.
            // The hunter is in the field — a crash means lost data from
            // the entire session. Better to lose one waypoint than everything.
            System.println("ERROR: Exception saving waypoint: " + ex.getErrorMessage());
        }
    }

    /**
     * onHide() — Clean up timer when view is hidden.
     */
    function onHide() as Void {
        if (_dismissTimer != null) {
            _dismissTimer.stop();
            _dismissTimer = null;
        }
    }
}

/**
 * PopChainHelper — Pops the view stack N times to return to a base view.
 *
 * WHY: Connect IQ's WatchUi.popView() cannot be called multiple times in
 * the same callback (re-entrancy causes a crash). Instead, each pop must
 * be scheduled on a separate timer tick. This class manages that chain.
 *
 * The first pop is done immediately (with a slide-down animation).
 * Subsequent pops are fired via 50ms timer delays, each using
 * SLIDE_IMMEDIATE so the intermediate screens flicker off invisibly.
 *
 * MEMORY: This object must be kept alive (referenced by the ConfirmationView)
 * during the entire chain — the timer holds a method() reference back to
 * this instance, which prevents it from being garbage collected.
 */
class PopChainHelper {

    var _timer as Timer.Timer?;
    var _popsLeft as Number;  // Remaining pops after the current one

    /**
     * @param totalPops — total number of views to pop (including the first one)
     */
    function initialize(totalPops as Number) {
        _popsLeft = totalPops - 1;  // First pop is done directly in startPopping()
    }

    /**
     * startPopping() — Begin the pop sequence.
     * Does the first pop immediately, then schedules the rest.
     */
    function startPopping() as Void {
        // First pop: animated slide-down so it looks intentional
        WatchUi.popView(WatchUi.SLIDE_DOWN);

        // Schedule remaining pops — each one fires 50ms after the last.
        // The 50ms gap gives the UI loop time to process the previous pop
        // before we issue the next one.
        if (_popsLeft > 0) {
            _timer = new Timer.Timer();
            _timer.start(method(:popNext), 50, false);
        }
    }

    /**
     * popNext() — Timer callback that pops one more view.
     * Re-schedules itself until _popsLeft reaches zero.
     */
    function popNext() as Void {
        if (_popsLeft <= 0) { return; }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _popsLeft--;

        if (_popsLeft > 0) {
            // Schedule the next pop
            _timer = new Timer.Timer();
            _timer.start(method(:popNext), 50, false);
        }
        // When _popsLeft == 0, the chain is done and the timer is not rescheduled.
        // This object will be GC'd after _popHelper in ConfirmationView is cleared.
    }
}

/**
 * ConfirmationDelegate — Minimal input handler for the confirmation screen.
 *
 * The screen auto-dismisses, but the user can also press any button
 * to dismiss it immediately (for speed).
 */
class ConfirmationDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    /**
     * onSelect() — Dismiss immediately (don't wait for auto-dismiss).
     */
    function onSelect() as Boolean {
        var view = WatchUi.getCurrentView()[0] as ConfirmationView;
        view.popToMainView();
        return true;
    }

    /**
     * onBack() — Also dismiss immediately.
     */
    function onBack() as Boolean {
        var view = WatchUi.getCurrentView()[0] as ConfirmationView;
        view.popToMainView();
        return true;
    }
}
