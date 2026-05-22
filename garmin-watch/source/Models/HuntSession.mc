import Toybox.Lang;
import Toybox.Time;
import Toybox.Application;
import Toybox.System;

/**
 * HuntSession — Tracks the current hunting session state.
 *
 * A "session" is one continuous hunt, from Start Hunt to End Hunt.
 * It tracks things that aren't persisted as waypoints but are
 * needed while the hunt is active:
 *   - Session start time (for filtering waypoints)
 *   - Distance traveled (for stats)
 *   - Last known position (for distance tracking)
 *
 * The session is NOT persisted to Object Store — it lives only
 * in memory. When the app restarts, a new session begins.
 * Waypoint data IS persisted independently via WaypointManager.
 */
class HuntSession {

    // When this hunt session started (Unix timestamp).
    // Used to filter waypoints for "this session only" stats.
    var _startTime as Number = 0;

    // Total distance traveled in meters.
    // Accumulated from GPS position updates.
    var _distanceTraveled as Double = 0.0d;

    // Last GPS position for incremental distance calculation.
    // Each time we get a new GPS fix, we calculate distance from
    // the last position and add it to _distanceTraveled.
    var _lastLat as Double? = null;
    var _lastLon as Double? = null;

    // Whether this session is currently active
    var _isActive as Boolean = false;

    /**
     * Constructor — creates an inactive session.
     * Call start() to begin the session.
     */
    function initialize() {
    }

    /**
     * start() — Begin a new hunt session.
     *
     * Resets all tracking data and records the start time.
     * Called when the user presses "Start Hunt."
     */
    function start() as Void {
        _startTime = Time.now().value();
        _distanceTraveled = 0.0d;
        _lastLat = null;
        _lastLon = null;
        _isActive = true;
        System.println("Hunt session started at " + _startTime);
    }

    /**
     * stop() — End the current hunt session.
     *
     * The session data stays in memory until a new session starts
     * so the Stats screen can still display it after ending.
     */
    function stop() as Void {
        _isActive = false;
        System.println("Hunt session ended. Distance: " +
            _distanceTraveled.format("%.0f") + "m");
    }

    /**
     * updatePosition() — Called on each GPS position update.
     *
     * Calculates the distance from the last known position to the
     * new position and adds it to the total distance traveled.
     * This gives us the total distance walked during the hunt.
     *
     * @param lat — new latitude in degrees
     * @param lon — new longitude in degrees
     */
    function updatePosition(lat as Double, lon as Double) as Void {
        if (!_isActive) {
            return;
        }

        if (_lastLat != null && _lastLon != null) {
            // Calculate distance from last position to new position
            var distance = CoordinateMath.haversineDistance(
                _lastLat as Double, _lastLon as Double, lat, lon
            );

            // Only add if the distance is meaningful (> 2 meters).
            // GPS jitter can cause small random jumps even when standing still.
            // Filtering out < 2m movements prevents false distance accumulation.
            if (distance > 2.0) {
                _distanceTraveled += distance;
            }
        }

        _lastLat = lat;
        _lastLon = lon;
    }

    /**
     * getDistanceTraveled() — Get total distance in meters.
     */
    function getDistanceTraveled() as Double {
        return _distanceTraveled;
    }

    /**
     * getDistanceMiles() — Get total distance in miles.
     */
    function getDistanceMiles() as Double {
        return _distanceTraveled / 1609.344;
    }

    /**
     * getDuration() — Get hunt duration in seconds.
     */
    function getDuration() as Number {
        if (_startTime == 0) {
            return 0;
        }
        return Time.now().value() - _startTime;
    }

    /**
     * getStartTime() — Get the session start timestamp.
     */
    function getStartTime() as Number {
        return _startTime;
    }

    /**
     * isActive() — Check if this session is currently running.
     */
    function isActive() as Boolean {
        return _isActive;
    }
}
