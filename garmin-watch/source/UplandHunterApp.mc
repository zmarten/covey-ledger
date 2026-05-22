import Toybox.Application;
import Toybox.Activity;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Position;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Sensor;

/**
 * UplandHunterApp — Main application entry point.
 *
 * This is the "root" of the entire app. Connect IQ calls onStart() when the
 * user launches the app, and onStop() when they exit. We manage:
 *   - Activity recording (creates the FIT file for Garmin Connect)
 *   - GPS position tracking (needed for waypoints)
 *   - Hunt session state (distance tracking, timing)
 *   - The initial view (MainView) that the user sees first
 *
 * KEY CONCEPT: Connect IQ apps are "view-based." You push views onto a stack.
 * The top view is what's displayed. When the user presses Back, the top view
 * pops off and the previous one shows. This class sets up the first view.
 */
class UplandHunterApp extends Application.AppBase {

    // The activity recording session — this creates the FIT file that syncs to Garmin Connect.
    // null when no activity is recording (before user starts a hunt).
    var _session as ActivityRecording.Session?;

    // Whether we have a valid GPS fix. Many features need this.
    var _hasGpsFix as Boolean = false;

    // Most recent GPS position info — updated by the position callback.
    // Can be null if GPS hasn't locked yet.
    var _lastPosition as Position.Info?;

    // Hunt start timestamp — set when activity recording begins.
    // Uses System.getTimer() (ms since app start) for elapsed time.
    var _huntStartTime as Number? = null;

    // The current hunt session — tracks distance, timing, etc.
    // Created fresh each time a new hunt starts.
    var _huntSession as HuntSession;

    // FIT custom fields — these add our hunting data to the FIT activity file
    // that syncs to Garmin Connect. FitContributor lets us define custom fields
    // that show up as "Developer Fields" in the activity.
    // These are session-level fields (totals for the whole hunt).
    var _fitFlushCount as FitContributor.Field?;
    var _fitBirdsDown as FitContributor.Field?;
    var _fitShotsCount as FitContributor.Field?;

    // Lap-level FIT fields — written once per flush, then _session.addLap() is
    // called to commit the lap record. Each flush becomes a distinct FIT lap so
    // third-party apps (CoveyTracker, Garmin Connect) can see per-flush detail.
    // Field IDs 3-8 continue the sequence from the session fields (0-2) above.
    var _fitLapSpecies as FitContributor.Field?;
    var _fitLapFlushed as FitContributor.Field?;
    var _fitLapBirdsDown as FitContributor.Field?;
    var _fitLapShotResult as FitContributor.Field?;
    var _fitLapLatitude as FitContributor.Field?;
    var _fitLapLongitude as FitContributor.Field?;

    // The real ANT+ dog tracker sensor — connects to the Alpha/Astro handheld.
    // Created on app start; open()/close() called with the hunt activity.
    var _dogTracker as DogTrackerSensor;

    // Breadcrumb trail positions for the map view.
    // Each entry is a [lat, lon] array (Doubles in degrees).
    // Sampled every 5 seconds during an active hunt.
    // Max 200 positions (~5KB memory, ~16 minutes of trail at 5s intervals).
    var _breadcrumbPositions as Array = [] as Array;

    // Unix timestamp of last breadcrumb position added.
    // Used to enforce the sampling interval (every 5 seconds).
    var _lastBreadcrumbTime as Number = 0;

    // Timestamp (System.getTimer() ms) of last processed GPS update.
    // Used to throttle GPS processing based on the gpsPollRate setting.
    // The GPS chip still runs continuously, but we skip callbacks that
    // arrive faster than the user's chosen poll rate to save CPU.
    var _lastGpsProcessTime as Number = 0;

    /**
     * Constructor — called once when the app is first created.
     * Keep this lightweight — heavy setup goes in onStart().
     */
    function initialize() {
        AppBase.initialize();
        _huntSession = new HuntSession();
        _dogTracker = new DogTrackerSensor();
    }

    /**
     * onStart() — called when the app launches.
     *
     * We enable GPS positioning here so we can capture coordinates
     * as soon as possible. GPS can take a few seconds to get a fix,
     * so starting early means it's ready by the time the user needs it.
     *
     * @param state — dictionary of saved app state (from onStop), or null
     */
    function onStart(state as Dictionary?) as Void {
        // Enable GPS position tracking.
        // Using continuous mode for real-time updates.
        // The callback function onPosition() fires each time we get new GPS data.
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    /**
     * onStop() — called when the app is exiting.
     *
     * Clean up resources: stop GPS, stop activity recording.
     * Failure to stop the activity session here would leave a
     * "zombie" activity recording in the background.
     *
     * @param state — dictionary where we can save state for next launch
     */
    function onStop(state as Dictionary?) as Void {
        // Stop GPS tracking to save battery
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));

        // If an activity is still recording, stop and save it.
        // Wrapped in try/catch — onStop MUST NOT crash, as it's our
        // last chance to save data before the app is killed.
        try {
            if (_session != null && _session.isRecording()) {
                _session.stop();
                _session.save();
            }
        } catch (ex) {
            System.println("WARNING: Failed to save activity on exit: " + ex.getErrorMessage());
        }
        _session = null;

        // End the hunt session tracking
        if (_huntSession.isActive()) {
            _huntSession.stop();
        }

        // Stop dog tracker on app exit
        _dogTracker.close();
    }

    /**
     * getSensorDelegate() — Return a SensorDelegate for System 8 native pairing.
     *
     * On System 8 devices, ANT sensors opened outside the native pairing flow
     * trigger a security warning dialog. By returning a SensorDelegate here,
     * we participate in the native pairing flow so the user can pair their
     * Alpha/Astro handheld through the system's standard UI.
     *
     * @return our DogTrackerPairingDelegate instance
     */
    function getSensorDelegate() as Sensor.SensorDelegate? {
        return new DogTrackerPairingDelegate();
    }

    /**
     * getInitialView() — Connect IQ calls this to get the first screen.
     *
     * Returns the main hunt screen (MainView) and its input handler (MainDelegate).
     * This is what the user sees when the app launches.
     *
     * @return Array of [View, InputDelegate] — the initial view stack
     */
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(), new MainDelegate()];
    }

    /**
     * onPosition() — GPS position callback.
     *
     * Called by the system every time we get a new GPS position fix.
     * We store the position info so other parts of the app can use it
     * (waypoint marking, distance calculations, etc.).
     *
     * Also updates the hunt session's distance tracking.
     *
     * @param info — the new position data (lat, lon, altitude, accuracy, etc.)
     */
    function onPosition(info as Position.Info) as Void {
        // Check if we actually have a valid position.
        // accuracy can be: QUALITY_NOT_AVAILABLE, QUALITY_LAST_KNOWN,
        // QUALITY_POOR, QUALITY_USABLE, QUALITY_GOOD
        if (info.accuracy != null && info.accuracy >= Position.QUALITY_USABLE) {
            _hasGpsFix = true;
        } else {
            _hasGpsFix = false;
        }

        // GPS throttling — skip processing if this callback arrived too soon.
        // The GPS chip fires callbacks continuously (~1/sec), but the user's
        // gpsPollRate setting controls how often we actually process the data.
        // This saves CPU cycles and reduces unnecessary screen redraws.
        var now = System.getTimer();
        var pollIntervalMs = Constants.getGpsPollInterval() * 1000;
        if (now - _lastGpsProcessTime < pollIntervalMs) {
            // Too soon — skip this update. We still updated _hasGpsFix above
            // so the GPS status indicator stays responsive.
            return;
        }
        _lastGpsProcessTime = now;

        // Store the latest position for other modules to read
        _lastPosition = info;

        // Update hunt session distance tracking and breadcrumb trail
        if (_hasGpsFix && _huntSession.isActive() &&
            info.position != null) {
            var coords = info.position.toDegrees();
            var lat = coords[0] as Double;
            var lon = coords[1] as Double;

            // Update distance tracking
            _huntSession.updatePosition(lat, lon);

            // Add breadcrumb position for the map trail.
            // Only sample every N seconds to limit memory usage.
            var bcTime = Time.now().value();
            if (bcTime - _lastBreadcrumbTime >= Constants.BREADCRUMB_SAMPLE_SECONDS) {
                // Remove oldest position if at capacity
                if (_breadcrumbPositions.size() >= Constants.MAX_BREADCRUMB_POSITIONS) {
                    _breadcrumbPositions = _breadcrumbPositions.slice(1, null) as Array;
                }
                _breadcrumbPositions.add([lat, lon]);
                _lastBreadcrumbTime = bcTime;
            }
        }

        // Request a screen update so the main view can show GPS status
        WatchUi.requestUpdate();
    }

    /**
     * startHuntActivity() — Begin recording a new hunt activity.
     *
     * Creates a FIT activity recording session and starts the hunt session.
     * This is what shows up in Garmin Connect as a "Hunting" activity.
     * We use SPORT_GENERIC since there's no built-in "Hunting" sport.
     */
    function startHuntActivity() as Void {
        // Don't start a new session if one is already active
        if (_session != null && _session.isRecording()) {
            return;
        }

        // Wrap activity creation in try/catch — if FIT recording fails,
        // we still want the hunt to start so waypoints can be recorded.
        // The hunter cares about marking flushes more than the FIT track.
        try {
            // Create a new activity recording session.
            // SPORT_HIKING is the closest built-in sport to upland hunting.
            // The name shows up in Garmin Connect as the activity title.
            _session = ActivityRecording.createSession({
                :name => "Upland Hunt",
                :sport => Activity.SPORT_HIKING,
                :subSport => Activity.SUB_SPORT_GENERIC
            });

            // Create custom FIT fields to store hunting data in the activity.
            // These show up as "Developer Fields" in Garmin Connect.
            // Field IDs (0, 1, 2) must be unique within our app.
            _fitFlushCount = _session.createField(
                "total_flushes",        // field name in FIT file
                0,                       // unique field ID
                FitContributor.DATA_TYPE_UINT16,  // unsigned 16-bit integer
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "count"}
            );
            _fitBirdsDown = _session.createField(
                "total_birds_down",
                1,
                FitContributor.DATA_TYPE_UINT16,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "count"}
            );
            _fitShotsCount = _session.createField(
                "shots_taken",
                2,
                FitContributor.DATA_TYPE_UINT16,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "count"}
            );

            // Initialize FIT fields to zero
            _fitFlushCount.setData(0);
            _fitBirdsDown.setData(0);
            _fitShotsCount.setData(0);

            // Create lap-level fields — one set of values is written per flush,
            // followed by _session.addLap() to commit the FIT lap record.
            // Field IDs 3-8 continue the session-field sequence above.
            _fitLapSpecies = _session.createField(
                "flush_species", 3, FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "enum"}
            );
            _fitLapFlushed = _session.createField(
                "flush_flushed", 4, FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "count"}
            );
            _fitLapBirdsDown = _session.createField(
                "flush_birds_down", 5, FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "count"}
            );
            _fitLapShotResult = _session.createField(
                "flush_shot_result", 6, FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "enum"}
            );
            _fitLapLatitude = _session.createField(
                "flush_latitude", 7, FitContributor.DATA_TYPE_SINT32,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "semicircles"}
            );
            _fitLapLongitude = _session.createField(
                "flush_longitude", 8, FitContributor.DATA_TYPE_SINT32,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "semicircles"}
            );

            // Start recording — from this point, GPS track points are logged to the FIT file
            _session.start();
        } catch (ex) {
            // FIT recording failed — log it but continue.
            // The hunt features (waypoints, dog tracking) still work without FIT.
            System.println("WARNING: Failed to start activity recording: " + ex.getErrorMessage());
            _session = null;
        }

        // Record when the hunt started for elapsed time display
        _huntStartTime = System.getTimer();

        // Clear the breadcrumb trail from any previous hunt
        _breadcrumbPositions = [] as Array;
        _lastBreadcrumbTime = 0;

        // Start the hunt session tracker (distance, etc.)
        _huntSession.start();

        // Start the real ANT+ dog tracker — opens a channel to the Alpha/Astro handheld.
        // The handheld must have "Broadcast Dog Data" enabled in its settings.
        _dogTracker.open();
    }

    /**
     * stopHuntActivity() — End and save the current hunt activity.
     *
     * Stops recording, saves the FIT file, and clears the session.
     * The FIT file will sync to Garmin Connect on next phone connection.
     */
    function stopHuntActivity() as Void {
        // Wrap FIT session stop in try/catch — if saving fails, we still
        // want to clean up the rest of the hunt state properly.
        try {
            if (_session != null && _session.isRecording()) {
                _session.stop();
                _session.save();
            }
        } catch (ex) {
            System.println("WARNING: Failed to save activity: " + ex.getErrorMessage());
        }
        _session = null;
        _huntStartTime = null;

        // Stop hunt session tracking
        if (_huntSession.isActive()) {
            _huntSession.stop();
        }

        // Stop the dog tracker — closes the ANT+ channel
        _dogTracker.close();
    }

    /**
     * isHuntActive() — Check if a hunt activity is currently being recorded.
     *
     * @return true if activity recording is in progress
     */
    function isHuntActive() as Boolean {
        return (_session != null && _session.isRecording());
    }

    /**
     * getHuntDuration() — Get elapsed hunt time in seconds.
     *
     * @return elapsed seconds, or 0 if no hunt is active
     */
    function getHuntDuration() as Number {
        if (_huntStartTime == null) {
            return 0;
        }
        // System.getTimer() returns milliseconds since app start
        return (System.getTimer() - _huntStartTime) / 1000;
    }

    /**
     * getHuntSession() — Access the current hunt session for stats/tracking.
     *
     * @return the HuntSession instance
     */
    function getHuntSession() as HuntSession {
        return _huntSession;
    }

    /**
     * updateFitData() — Update the FIT custom fields with current stats.
     *
     * Called after each waypoint is saved to keep the FIT activity file
     * in sync with our hunting data. When the activity ends and the FIT
     * file is saved, these values are included in the session summary.
     *
     * @param totalFlushes — total number of flushes in this session
     * @param totalDown — total birds downed in this session
     * @param totalShots — total shots taken in this session
     */
    function updateFitData(totalFlushes as Number, totalDown as Number,
                            totalShots as Number) as Void {
        if (_fitFlushCount != null) {
            _fitFlushCount.setData(totalFlushes);
        }
        if (_fitBirdsDown != null) {
            _fitBirdsDown.setData(totalDown);
        }
        if (_fitShotsCount != null) {
            _fitShotsCount.setData(totalShots);
        }
    }

    /**
     * recordFlushLap() — Write per-flush detail into a FIT lap record.
     *
     * Populates the six lap-level developer fields with this flush's data,
     * then calls _session.addLap() to commit the lap record to the FIT file.
     * Each flush becomes a distinct FIT lap, enabling third-party apps such
     * as CoveyTracker to reconstruct the full flush log from a single FIT file.
     *
     * Coordinate conversion: FIT stores position in semicircles where
     * 1 degree = 2^31 / 180 = 11,930,464.71 semicircles. We round to the
     * nearest integer (toNumber() truncates, so we multiply by the precise
     * factor and accept sub-meter rounding error — well within GPS accuracy).
     *
     * @param species     — SPECIES_* constant (0-10)
     * @param flushed     — number of birds flushed (same as _quantityFlushed)
     * @param birdsDown   — number of birds downed (0 if no shot or missed)
     * @param shotResult  — SHOT_HIT / SHOT_MISSED / SHOT_NO_SHOT constant
     * @param lat         — flush latitude in decimal degrees
     * @param lon         — flush longitude in decimal degrees
     */
    function recordFlushLap(species as Number, flushed as Number,
                             birdsDown as Number, shotResult as Number,
                             lat as Double, lon as Double) as Void {
        if (_session != null && _session.isRecording()) {
            try {
                if (_fitLapSpecies != null) { _fitLapSpecies.setData(species); }
                if (_fitLapFlushed != null) { _fitLapFlushed.setData(flushed); }
                if (_fitLapBirdsDown != null) { _fitLapBirdsDown.setData(birdsDown); }
                if (_fitLapShotResult != null) { _fitLapShotResult.setData(shotResult); }
                if (_fitLapLatitude != null) { _fitLapLatitude.setData((lat * 11930465.0).toNumber()); }
                if (_fitLapLongitude != null) { _fitLapLongitude.setData((lon * 11930465.0).toNumber()); }
                _session.addLap();
            } catch (ex) {
                // Non-fatal — the waypoint is already saved to Object Store.
                // Losing the FIT lap is unfortunate but not catastrophic.
                System.println("FIT lap record error: " + ex.getErrorMessage());
            }
        }
    }
}
