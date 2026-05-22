import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

/**
 * WaypointManager — Handles saving, loading, and managing waypoints.
 *
 * Uses the Garmin Object Store API for persistent storage. The Object Store
 * survives app restarts, watch reboots, and even firmware updates. It's a
 * key-value store where keys are strings and values are serializable types.
 *
 * STORAGE STRATEGY:
 *   - Key "waypoint_ids": Array of all waypoint IDs (timestamps)
 *   - Key "wp_<id>": Individual waypoint data (Dictionary)
 *   - Key "waypoint_count": Total count (Number) for quick access
 *
 * WHY NOT store all waypoints in one big array?
 *   Connect IQ has limits on individual Object Store entry sizes.
 *   By storing each waypoint separately, we can handle hundreds
 *   of waypoints without hitting size limits. The ID list is small
 *   (just an array of numbers) and serves as an index.
 *
 * THREAD SAFETY: Connect IQ is single-threaded, so we don't need
 * locks or synchronization. All code runs on the main thread.
 */
module WaypointManager {

    // Object Store keys
    const STORE_KEY_IDS = "waypoint_ids";
    const STORE_KEY_COUNT = "waypoint_count";
    const STORE_KEY_PREFIX = "wp_";

    /**
     * saveWaypoint() — Save a new waypoint to persistent storage.
     *
     * Adds the waypoint's dictionary representation to the Object Store
     * and updates the ID index. If we've hit the max waypoint limit,
     * the oldest waypoint is removed to make room.
     *
     * @param waypoint — the Waypoint to save
     * @return true if saved successfully, false on error
     */
    function saveWaypoint(waypoint as Waypoint) as Boolean {
        try {
            // Get the current list of waypoint IDs
            var ids = getWaypointIds();

            // Check capacity — remove oldest if at max
            if (ids.size() >= Constants.MAX_WAYPOINTS) {
                // Remove the oldest waypoint (first in the list)
                var oldestId = ids[0] as Number;
                removeWaypointById(oldestId);
                ids = ids.slice(1, null); // Remove first element
            }

            // Save the waypoint data
            var key = STORE_KEY_PREFIX + waypoint.id.toString();
            Application.Storage.setValue(key, waypoint.toDictionary());

            // Add this waypoint's ID to the index
            ids.add(waypoint.id);
            Application.Storage.setValue(STORE_KEY_IDS, ids);
            Application.Storage.setValue(STORE_KEY_COUNT, ids.size());

            System.println("Saved waypoint #" + waypoint.id + " (" +
                Constants.getSpeciesName(waypoint.species) + ")");
            return true;

        } catch (ex) {
            System.println("ERROR saving waypoint: " + ex.getErrorMessage());
            return false;
        }
    }

    /**
     * loadWaypoint() — Load a single waypoint by its ID.
     *
     * @param id — the waypoint ID (timestamp)
     * @return the Waypoint object, or null if not found
     */
    function loadWaypoint(id as Number) as Waypoint? {
        var key = STORE_KEY_PREFIX + id.toString();
        var dict = Application.Storage.getValue(key);

        if (dict == null) {
            return null;
        }

        return Waypoint.fromDictionary(dict as Dictionary);
    }

    /**
     * loadAllWaypoints() — Load all stored waypoints.
     *
     * Returns an array of Waypoint objects in chronological order
     * (oldest first). Used by the Stats screen and Map view.
     *
     * NOTE: This loads ALL waypoints into memory at once.
     * With 500 waypoints at ~100 bytes each, that's ~50KB.
     * Call this only when needed, not on every screen refresh.
     *
     * @return Array of Waypoint objects
     */
    function loadAllWaypoints() as Array<Waypoint> {
        var ids = getWaypointIds();
        var waypoints = [] as Array<Waypoint>;

        for (var i = 0; i < ids.size(); i++) {
            var wp = loadWaypoint(ids[i] as Number);
            if (wp != null) {
                waypoints.add(wp);
            }
        }

        return waypoints;
    }

    /**
     * getWaypointIds() — Get the list of all stored waypoint IDs.
     *
     * @return Array of waypoint IDs (Numbers), or empty array if none
     */
    function getWaypointIds() as Array<Number> {
        var stored = Application.Storage.getValue(STORE_KEY_IDS);
        if (stored == null) {
            return [] as Array<Number>;
        }
        return stored as Array<Number>;
    }

    /**
     * getWaypointCount() — Get the number of stored waypoints.
     *
     * Uses the cached count for speed instead of loading the ID array.
     *
     * @return number of waypoints in storage
     */
    function getWaypointCount() as Number {
        var count = Application.Storage.getValue(STORE_KEY_COUNT);
        if (count == null) {
            return 0;
        }
        return count as Number;
    }

    /**
     * removeWaypointById() — Delete a specific waypoint from storage.
     *
     * @param id — the waypoint ID to remove
     */
    function removeWaypointById(id as Number) as Void {
        // Delete the waypoint data
        var key = STORE_KEY_PREFIX + id.toString();
        Application.Storage.deleteValue(key);

        // Remove from the ID index
        var ids = getWaypointIds();
        var newIds = [] as Array<Number>;
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] != id) {
                newIds.add(ids[i] as Number);
            }
        }
        Application.Storage.setValue(STORE_KEY_IDS, newIds);
        Application.Storage.setValue(STORE_KEY_COUNT, newIds.size());
    }

    /**
     * clearAllWaypoints() — Remove all waypoints from storage.
     *
     * Used when ending a hunt session or clearing data.
     * WARNING: This is destructive and cannot be undone!
     */
    function clearAllWaypoints() as Void {
        var ids = getWaypointIds();

        // Delete each waypoint's data entry
        for (var i = 0; i < ids.size(); i++) {
            var key = STORE_KEY_PREFIX + (ids[i] as Number).toString();
            Application.Storage.deleteValue(key);
        }

        // Clear the index
        Application.Storage.setValue(STORE_KEY_IDS, [] as Array<Number>);
        Application.Storage.setValue(STORE_KEY_COUNT, 0);

        System.println("Cleared all waypoints from storage");
    }

    /**
     * getSessionWaypoints() — Load waypoints from the current hunt session only.
     *
     * Filters waypoints by timestamp, returning only those recorded
     * after the hunt session started. Used by Stats to show current
     * session data, not historical data.
     *
     * @param sessionStartTime — the unix timestamp when the hunt started
     * @return Array of Waypoint objects from this session
     */
    function getSessionWaypoints(sessionStartTime as Number) as Array<Waypoint> {
        var all = loadAllWaypoints();
        var session = [] as Array<Waypoint>;

        for (var i = 0; i < all.size(); i++) {
            if (all[i].timestamp >= sessionStartTime) {
                session.add(all[i]);
            }
        }

        return session;
    }
}
