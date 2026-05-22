import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

/**
 * BirdMarker — Data model for a single downed bird location.
 *
 * When a hunter marks a downed bird, we calculate the estimated
 * GPS position based on their current position + compass bearing + distance.
 * This marker holds that estimated position and metadata so the
 * navigation screen can guide them to it.
 *
 * Markers persist while the app is running. The hunter can:
 *   - Navigate to any active marker
 *   - Mark a bird as "retrieved" (removes the marker)
 *   - Leave markers active and return to hunting ("back to hunt")
 */
class BirdMarker {

    // Estimated GPS position of the downed bird (in degrees)
    var targetLat as Double;
    var targetLon as Double;

    // Where the hunter was standing when they marked the bird
    var originLat as Double;
    var originLon as Double;

    // Compass bearing from origin to target (degrees, 0-360)
    var bearing as Double;

    // Estimated distance from origin to target (yards)
    var distanceYards as Number;

    // When this marker was created (unix timestamp)
    var timestamp as Number;

    // Unique ID for this marker
    var id as Number;

    // Whether this bird has been retrieved
    var isRetrieved as Boolean = false;

    /**
     * Constructor — create a new bird marker.
     *
     * @param tLat — estimated target latitude (where the bird is)
     * @param tLon — estimated target longitude
     * @param oLat — origin latitude (where the hunter stood)
     * @param oLon — origin longitude
     * @param bear — compass bearing from origin to target (degrees)
     * @param dist — estimated distance in yards
     */
    function initialize(tLat as Double, tLon as Double,
                         oLat as Double, oLon as Double,
                         bear as Double, dist as Number) {
        targetLat = tLat;
        targetLon = tLon;
        originLat = oLat;
        originLon = oLon;
        bearing = bear;
        distanceYards = dist;
        timestamp = Time.now().value();
        id = timestamp; // Use timestamp as unique ID
        isRetrieved = false;
    }
}

/**
 * BirdMarkerManager — Manages multiple downed bird markers.
 *
 * Hunters can mark up to 10 birds (Constants.MAX_BIRD_MARKERS).
 * This module provides add/remove/get operations for the marker list.
 *
 * Markers are stored in memory only (not persisted to Object Store)
 * since they're temporary — once a bird is retrieved, the marker
 * is removed. If the app restarts, markers are lost, which is
 * acceptable since the hunt context has changed.
 */
module BirdMarkerManager {

    // In-memory list of active bird markers.
    // Module-level var acts like a singleton — one list for the whole app.
    var _markers as Array<BirdMarker> = [] as Array<BirdMarker>;

    /**
     * addMarker() — Add a new bird marker.
     *
     * If we're at the maximum (10), the oldest marker is removed
     * to make room. This prevents unbounded memory growth.
     *
     * @param marker — the BirdMarker to add
     */
    function addMarker(marker as BirdMarker) as Void {
        // Enforce the maximum marker limit
        if (_markers.size() >= Constants.MAX_BIRD_MARKERS) {
            _markers = _markers.slice(1, null) as Array<BirdMarker>;
        }
        _markers.add(marker);
        System.println("Bird marker added. Total: " + _markers.size());
    }

    /**
     * removeMarker() — Remove a marker by its ID.
     *
     * Called when a bird is retrieved — the marker is no longer needed.
     *
     * @param id — the marker ID to remove
     */
    function removeMarker(id as Number) as Void {
        var newList = [] as Array<BirdMarker>;
        for (var i = 0; i < _markers.size(); i++) {
            if (_markers[i].id != id) {
                newList.add(_markers[i]);
            }
        }
        _markers = newList;
    }

    /**
     * getMarkers() — Get all active (non-retrieved) markers.
     *
     * @return Array of active BirdMarker objects
     */
    function getMarkers() as Array<BirdMarker> {
        return _markers;
    }

    /**
     * getMarkerCount() — How many active markers exist.
     */
    function getMarkerCount() as Number {
        return _markers.size();
    }

    /**
     * getMarkerById() — Find a specific marker by ID.
     *
     * @param id — the marker ID
     * @return the BirdMarker, or null if not found
     */
    function getMarkerById(id as Number) as BirdMarker? {
        for (var i = 0; i < _markers.size(); i++) {
            if (_markers[i].id == id) {
                return _markers[i];
            }
        }
        return null;
    }

    /**
     * clearAll() — Remove all markers.
     * Called when ending a hunt session.
     */
    function clearAll() as Void {
        _markers = [] as Array<BirdMarker>;
    }
}
