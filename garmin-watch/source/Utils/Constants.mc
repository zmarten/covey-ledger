import Toybox.Lang;
import Toybox.Application;

/**
 * Constants — Central location for all app-wide constant values.
 *
 * WHY: Hardcoding values like colors or species IDs in views creates bugs.
 * If you change a color in one place but forget another, things break.
 * By defining everything here, there's one source of truth.
 *
 * HOW TO USE: Reference these anywhere with Constants.COLOR_PRIMARY, etc.
 * Monkey C treats these as compile-time constants, so there's zero
 * runtime cost — the compiler inlines the values.
 */
module Constants {

    // =========================================================================
    // COLOR PALETTE
    // These match the design spec in PRODUCT_BRIEF.md section 4.2.
    // All colors are 24-bit RGB (0xRRGGBB format).
    // AMOLED screens show pure black (0x000000) as completely off pixels,
    // which saves battery. That's why our background is dark gray, not black.
    // =========================================================================

    /** Orange — primary action color. Headers, active buttons, highlighted items. */
    const COLOR_PRIMARY    = 0xEA580C;

    /** Green — success/positive. Shot birds, close distance, GPS ready. */
    const COLOR_SUCCESS    = 0x16A34A;

    /** Red — alert/danger. Point alerts, far distance, downed bird markers. */
    const COLOR_ALERT      = 0xDC2626;

    /** Yellow — warning/caution. Medium distance, attention needed. */
    const COLOR_WARNING    = 0xEAB308;

    /** Dark gray — background color. Dark enough for AMOLED efficiency. */
    const COLOR_BG         = 0x1F2937;

    /** White — primary text on dark backgrounds. */
    const COLOR_TEXT       = 0xFFFFFF;

    /** Gray — secondary/muted text. Labels, hints, disabled states. */
    const COLOR_MUTED      = 0x9CA3AF;

    // High contrast mode colors (for bright sunlight)
    /** Pure black background for maximum AMOLED contrast in sunlight. */
    const COLOR_HC_BG      = 0x000000;

    /** Pure white text for high contrast mode. */
    const COLOR_HC_TEXT    = 0xFFFFFF;

    // =========================================================================
    // SPECIES ENUM
    // Each bird species gets a unique integer ID. This is what we store
    // in waypoints and FIT files — not the species name string.
    // Using integers saves memory and makes comparisons fast.
    // =========================================================================

    const SPECIES_PHEASANT        = 0;
    const SPECIES_QUAIL           = 1;
    const SPECIES_CHUKAR          = 2;
    const SPECIES_GROUSE_RUFFED   = 3;
    const SPECIES_GROUSE_SAGE     = 4;
    const SPECIES_GROUSE_SHARPTAIL = 5;
    const SPECIES_WOODCOCK        = 6;
    const SPECIES_PRAIRIE_CHICKEN = 7;
    const SPECIES_PARTRIDGE       = 8;
    const SPECIES_DOVE            = 9;
    const SPECIES_OTHER           = 10;

    /** Total number of species — used for array sizing and loop bounds. */
    const SPECIES_COUNT           = 11;

    /**
     * getSpeciesName() — Convert a species enum value to a display string.
     *
     * Used whenever we need to show the species name to the user
     * (flush confirmation, stats breakdown, etc.).
     *
     * @param species — one of the SPECIES_* constants above
     * @return the human-readable species name
     */
    function getSpeciesName(species as Number) as String {
        switch (species) {
            case SPECIES_PHEASANT:        return "Pheasant";
            case SPECIES_QUAIL:           return "Quail";
            case SPECIES_CHUKAR:          return "Chukar";
            case SPECIES_GROUSE_RUFFED:   return "Grouse (Ruffed)";
            case SPECIES_GROUSE_SAGE:     return "Grouse (Sage)";
            case SPECIES_GROUSE_SHARPTAIL: return "Grouse (Sharp-tail)";
            case SPECIES_WOODCOCK:        return "Woodcock";
            case SPECIES_PRAIRIE_CHICKEN: return "Prairie Chicken";
            case SPECIES_PARTRIDGE:       return "Partridge";
            case SPECIES_DOVE:            return "Dove";
            case SPECIES_OTHER:           return "Other";
            default:                      return "Unknown";
        }
    }

    // =========================================================================
    // SHOT RESULT ENUM
    // What happened when the bird flushed — did the hunter shoot?
    // =========================================================================

    /** Hunter fired and hit at least one bird. */
    const SHOT_HIT     = 0;

    /** Hunter fired but missed. */
    const SHOT_MISSED  = 1;

    /** Bird flushed but hunter didn't shoot (out of range, wrong species, etc.). */
    const SHOT_NO_SHOT = 2;

    // =========================================================================
    // DOG STATUS ENUM
    // Status codes from the ANT+ dog tracker data.
    // The Alpha/Astro handheld reports each dog's current activity state.
    // =========================================================================

    /** Dog is actively moving around. */
    const DOG_STATUS_MOVING     = 0;

    /** Dog has stopped moving — might be on scent, resting, etc. */
    const DOG_STATUS_STATIONARY = 1;

    /** Dog is on point — frozen, indicating birds! This triggers an alert. */
    const DOG_STATUS_ON_POINT   = 2;

    /** Dog has treed an animal. Similar alert to on-point. */
    const DOG_STATUS_TREED      = 3;

    /** Dog's GPS collar lost satellite signal. Position is stale. */
    const DOG_STATUS_GPS_LOST   = 4;

    /** Communication lost between collar and handheld. No data. */
    const DOG_STATUS_COMM_LOST  = 5;

    // =========================================================================
    // ANT+ CONNECTION STATE
    // Tracks the state of our ANT+ connection to the Alpha/Astro handheld.
    // =========================================================================

    /** Not searching, not connected. Initial state. */
    const ANT_STATE_IDLE        = 0;

    /** Actively searching for a handheld to connect to. */
    const ANT_STATE_SEARCHING   = 1;

    /** Connected to a handheld and receiving dog data. */
    const ANT_STATE_CONNECTED   = 2;

    /** Was connected but lost the connection. Will auto-retry. */
    const ANT_STATE_LOST        = 3;

    // =========================================================================
    // DISTANCE THRESHOLDS (in yards)
    // Used for color-coding dog distances.
    // Green = close, Yellow = medium, Red = far.
    // =========================================================================

    /** Dogs closer than this are shown in green. */
    const DISTANCE_CLOSE_THRESHOLD  = 30;

    /** Dogs between close and far are shown in yellow. Beyond this = red. */
    const DISTANCE_FAR_THRESHOLD    = 100;

    // =========================================================================
    // UI CONSTANTS
    // Sizing, timing, and layout values used across all views.
    // =========================================================================

    /** Minimum touch target size in pixels. Hunters wear gloves! */
    const MIN_TOUCH_TARGET = 60;

    /** Button debounce time in milliseconds. Prevents double-taps from gloves. */
    const DEBOUNCE_MS = 500;

    /** How long the confirmation screen shows before auto-dismissing (ms). */
    const CONFIRMATION_TIMEOUT_MS = 2000;

    /** Maximum number of simultaneous downed bird markers. */
    const MAX_BIRD_MARKERS = 10;

    /** Maximum number of dogs to display in the UI. */
    const MAX_DOGS_DISPLAY = 20;

    /** Maximum number of waypoints to store (memory constraint). */
    const MAX_WAYPOINTS = 500;

    /** Maximum breadcrumb trail positions to store for the map view. */
    const MAX_BREADCRUMB_POSITIONS = 200;

    /** How often to record a breadcrumb position, in seconds. */
    const BREADCRUMB_SAMPLE_SECONDS = 5;

    // =========================================================================
    // GPS POLLING INTERVALS (in milliseconds)
    // Configurable via settings. Lower = more accurate, more battery drain.
    // =========================================================================

    /** Battery saver mode — update every 5 seconds. */
    const GPS_POLL_BATTERY_SAVER = 5000;

    /** Standard mode — update every 2 seconds. Good balance. */
    const GPS_POLL_STANDARD      = 2000;

    /** High accuracy mode — update every second. Best for marking birds. */
    const GPS_POLL_HIGH_ACCURACY = 1000;

    // =========================================================================
    // MATH CONSTANTS
    // Used in coordinate calculations (haversine formula, bearing, etc.).
    // =========================================================================

    /** Earth's radius in meters. Used for haversine distance calculations. */
    const EARTH_RADIUS_M = 6371000.0;

    /** Conversion factor: yards to meters. Multiply yards by this. */
    const YARDS_TO_METERS = 0.9144;

    /** Conversion factor: meters to yards. Multiply meters by this. */
    const METERS_TO_YARDS = 1.09361;

    /** Pi constant for trig calculations. */
    const PI = 3.14159265358979;

    /** Degrees to radians conversion factor. Multiply degrees by this. */
    const DEG_TO_RAD = 0.01745329251994;

    /** Radians to degrees conversion factor. Multiply radians by this. */
    const RAD_TO_DEG = 57.2957795130823;

    // =========================================================================
    // SETTINGS HELPER FUNCTIONS
    // Centralized access to user settings so every view doesn't need to
    // duplicate Application.Properties.getValue() calls and null checks.
    // =========================================================================

    /**
     * getBgColor() — Returns the background color based on high contrast setting.
     *
     * High contrast mode uses pure black (0x000000) instead of dark gray.
     * Pure black on AMOLED = pixels completely off = maximum readability in
     * bright sunlight AND better battery life.
     *
     * @return COLOR_HC_BG if high contrast enabled, COLOR_BG otherwise
     */
    function getBgColor() as Number {
        var hc = Application.Properties.getValue("highContrast");
        if (hc != null && hc) {
            return COLOR_HC_BG;
        }
        return COLOR_BG;
    }

    /**
     * getTextColor() — Returns the primary text color based on high contrast setting.
     *
     * Both modes use white text currently, but this function exists so we
     * can easily change the high-contrast text color later if needed.
     *
     * @return COLOR_HC_TEXT if high contrast enabled, COLOR_TEXT otherwise
     */
    function getTextColor() as Number {
        var hc = Application.Properties.getValue("highContrast");
        if (hc != null && hc) {
            return COLOR_HC_TEXT;
        }
        return COLOR_TEXT;
    }

    /**
     * isHighContrast() — Check if high contrast mode is enabled.
     *
     * @return true if user has high contrast mode on
     */
    function isHighContrast() as Boolean {
        var hc = Application.Properties.getValue("highContrast");
        return (hc != null && hc);
    }

    /**
     * isMetric() — Check if the user prefers metric units (meters/km).
     *
     * The unitSystem setting: 0 = yards/miles (US default), 1 = meters/km.
     *
     * @return true if metric, false if imperial (yards)
     */
    function isMetric() as Boolean {
        var unit = Application.Properties.getValue("unitSystem");
        return (unit != null && unit == 1);
    }

    /**
     * formatDogDistance() — Format a dog's distance in the user's preferred units.
     *
     * Converts from yards (the internal unit) to meters if the user chose metric.
     *
     * @param distanceYards — distance in yards (from ANT+ data)
     * @return formatted string like "45 yd" or "41 m"
     */
    function formatDogDistance(distanceYards as Number) as String {
        if (isMetric()) {
            var meters = (distanceYards.toDouble() * YARDS_TO_METERS).toNumber();
            return meters.format("%d") + " m";
        }
        return distanceYards.format("%d") + " yd";
    }

    /**
     * formatNavigationDistance() — Format a navigation distance (Double, in meters).
     *
     * Used by NavigationView to show distance to downed bird.
     * Converts meters → yards if imperial, keeps meters if metric.
     *
     * @param distanceMeters — distance in meters
     * @return formatted string like "45 yd" or "41 m"
     */
    function formatNavigationDistance(distanceMeters as Double) as String {
        if (isMetric()) {
            return distanceMeters.format("%d") + " m";
        }
        var yards = CoordinateMath.metersToYards(distanceMeters);
        return yards.format("%d") + " yd";
    }

    /**
     * getDistanceUnitLabel() — Return the unit label string ("yards" or "meters").
     *
     * Used on the DistanceEntryView below the number counter.
     *
     * @return "meters" if metric, "yards" if imperial
     */
    function getDistanceUnitLabel() as String {
        return isMetric() ? "meters" : "yards";
    }

    /**
     * formatStatDistance() — Format session distance for stats display.
     *
     * Shows miles for imperial, km for metric.
     *
     * @param miles — distance in miles (from HuntSession)
     * @return formatted string like "2.4 mi" or "3.9 km"
     */
    function formatStatDistance(miles as Double) as String {
        if (isMetric()) {
            var km = miles * 1.60934;
            return km.format("%.1f") + " km";
        }
        return miles.format("%.1f") + " mi";
    }

    /**
     * getGpsPollInterval() — Return the GPS throttle interval in seconds.
     *
     * Based on the gpsPollRate setting:
     *   0 = battery saver → process GPS every 5 seconds
     *   1 = standard → process GPS every 2 seconds
     *   2 = high accuracy → process every GPS update (1 second)
     *
     * This throttles how often we PROCESS GPS data in onPosition().
     * The GPS chip still runs at its native rate — we just skip callbacks
     * we don't need, saving CPU cycles and reducing screen redraws.
     *
     * @return interval in seconds between processed GPS updates
     */
    function getGpsPollInterval() as Number {
        var rate = Application.Properties.getValue("gpsPollRate");
        if (rate != null) {
            if (rate == 0) { return 5; }  // Battery saver
            if (rate == 2) { return 1; }  // High accuracy
        }
        return 2;  // Standard (default)
    }
}
