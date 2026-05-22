import Toybox.Lang;
import Toybox.Time;

/**
 * DogData — Data model for a single tracked dog.
 *
 * Holds all the information the app displays about each dog:
 * name, distance, direction, status, battery, etc.
 *
 * This class is populated by either:
 *   - DogTrackerMock (fake data for development/testing)
 *   - DogTrackerSensor (real ANT+ data from Alpha/Astro handheld)
 *
 * Both sources create and update DogData objects with the same fields,
 * so the rest of the app (MainView, MapView) doesn't need to know
 * which source is active.
 *
 * DATA FLOW:
 *   Alpha/Astro handheld → ANT+ broadcast → DogTrackerSensor → DogData
 *   OR: DogTrackerMock timer → DogData
 *   → MainView reads DogData for display
 *   → HuntMapView reads DogData for map markers
 *   → Alert system checks DogData.status for ON POINT / TREED
 */
class DogData {

    // The dog's name (from ANT+ name packets or mock data)
    var name as String;

    // Unique identifier for this dog (from ANT+ dog index or assigned)
    var id as Number;

    // Distance from the handheld to the dog in yards.
    // The handheld calculates this from GPS coordinates.
    // Color-coded in the UI: green < 30yd, yellow 30-100yd, red > 100yd.
    var distanceYards as Number;

    // Compass bearing from the handheld/watch to the dog (0-360 degrees).
    // 0 = north, 90 = east, 180 = south, 270 = west.
    var direction as Double;

    // Dog's current activity state.
    // One of the Constants.DOG_STATUS_* values:
    //   MOVING, STATIONARY, ON_POINT, TREED, GPS_LOST, COMM_LOST
    var status as Number;

    // Dog collar battery level (0-100 percent).
    // Not all ANT+ packets include this — may stay at default.
    var batteryPercent as Number;

    // Signal quality between handheld and collar (0-100).
    // Higher = stronger signal. 0 = no signal / comm lost.
    var signalQuality as Number;

    // Unix timestamp of the last data update for this dog.
    // Used to detect stale data (dog hasn't been heard from recently).
    var lastUpdateTime as Number;

    // Collar color index (0-based, from ANT+ color packet).
    // Used for UI theming if desired. 0 = default.
    var color as Number;

    // Estimated GPS coordinates of the dog (in degrees).
    // May be null if only distance/direction is available.
    // When null, the map can calculate position from the hunter's
    // location + this dog's distance + direction.
    var latitude as Double?;
    var longitude as Double?;

    /**
     * Constructor — create a new dog data entry.
     *
     * Starts with "comm lost" status since we haven't received
     * data from this dog yet. All values are at defaults until
     * updated by the data source (mock or ANT+).
     *
     * @param dogName — the dog's display name
     * @param dogId — unique identifier (ANT+ dog index)
     */
    function initialize(dogName as String, dogId as Number) {
        name = dogName;
        id = dogId;
        distanceYards = 0;
        direction = 0.0d;
        status = Constants.DOG_STATUS_COMM_LOST;
        batteryPercent = 100;
        signalQuality = 0;
        lastUpdateTime = 0;
        color = 0;
        latitude = null;
        longitude = null;
    }
}
