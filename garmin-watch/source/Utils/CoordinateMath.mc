import Toybox.Application;
import Toybox.Math;
import Toybox.Lang;
import Toybox.Position;

/**
 * CoordinateMath — GPS coordinate math utilities.
 *
 * This module handles all the spherical geometry we need for the app:
 *   - Haversine formula: calculate distance between two GPS points
 *   - Bearing calculation: compass direction from one point to another
 *   - Destination point: given a start point + bearing + distance, find the end point
 *   - Cardinal direction: convert degrees to N, NE, E, etc.
 *
 * ALL MATH HERE USES RADIANS internally. Input/output is in degrees
 * (because that's what GPS and compass give us), but we convert to
 * radians for the trig functions.
 *
 * WHY HAVERSINE: The Earth is (roughly) a sphere. "Flat" distance formulas
 * (Pythagorean theorem) don't work for GPS coordinates because lines of
 * longitude converge at the poles. Haversine accounts for the curvature.
 * For the short distances we deal with (< 1 mile typically), it's plenty accurate.
 */
module CoordinateMath {

    /**
     * haversineDistance() — Calculate distance between two GPS points.
     *
     * Uses the Haversine formula, which gives great-circle distance
     * (shortest path along the Earth's surface) between two points
     * specified by latitude and longitude.
     *
     * Accuracy: better than 0.5% for distances under 10km.
     * That's way more accurate than consumer GPS (~3-5m error).
     *
     * @param lat1 — latitude of point 1, in DEGREES (e.g., 43.6532)
     * @param lon1 — longitude of point 1, in DEGREES (e.g., -116.6735)
     * @param lat2 — latitude of point 2, in DEGREES
     * @param lon2 — longitude of point 2, in DEGREES
     * @return distance in METERS between the two points
     */
    function haversineDistance(lat1 as Double, lon1 as Double,
                               lat2 as Double, lon2 as Double) as Double {
        // Step 1: Convert all coordinates from degrees to radians.
        // Trig functions (sin, cos) expect radians.
        var lat1Rad = lat1 * Constants.DEG_TO_RAD;
        var lon1Rad = lon1 * Constants.DEG_TO_RAD;
        var lat2Rad = lat2 * Constants.DEG_TO_RAD;
        var lon2Rad = lon2 * Constants.DEG_TO_RAD;

        // Step 2: Calculate differences
        var dLat = lat2Rad - lat1Rad;
        var dLon = lon2Rad - lon1Rad;

        // Step 3: Haversine formula
        // a = sin²(dLat/2) + cos(lat1) * cos(lat2) * sin²(dLon/2)
        // This is the square of half the chord length between the points.
        var sinDLatHalf = Math.sin(dLat / 2.0);
        var sinDLonHalf = Math.sin(dLon / 2.0);
        var a = sinDLatHalf * sinDLatHalf +
                Math.cos(lat1Rad) * Math.cos(lat2Rad) *
                sinDLonHalf * sinDLonHalf;

        // Step 4: c = 2 * atan2(sqrt(a), sqrt(1-a))
        // This is the angular distance in radians.
        var c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));

        // Step 5: distance = Earth's radius * angular distance
        return Constants.EARTH_RADIUS_M * c;
    }

    /**
     * calculateBearing() — Calculate initial compass bearing from point 1 to point 2.
     *
     * Returns the compass heading you'd need to face to walk from
     * point 1 directly toward point 2. This is the "initial bearing"
     * (also called "forward azimuth").
     *
     * Note: For short distances (< 1km), the bearing stays roughly constant.
     * For long distances, the bearing changes as you walk (great circle path).
     *
     * @param lat1 — latitude of start point, in DEGREES
     * @param lon1 — longitude of start point, in DEGREES
     * @param lat2 — latitude of destination, in DEGREES
     * @param lon2 — longitude of destination, in DEGREES
     * @return bearing in DEGREES (0-360, where 0=North, 90=East, 180=South, 270=West)
     */
    function calculateBearing(lat1 as Double, lon1 as Double,
                               lat2 as Double, lon2 as Double) as Double {
        // Convert to radians
        var lat1Rad = lat1 * Constants.DEG_TO_RAD;
        var lat2Rad = lat2 * Constants.DEG_TO_RAD;
        var dLonRad = (lon2 - lon1) * Constants.DEG_TO_RAD;

        // Bearing formula:
        // theta = atan2(sin(dLon) * cos(lat2),
        //               cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon))
        var y = Math.sin(dLonRad) * Math.cos(lat2Rad);
        var x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
                Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLonRad);

        var bearing = Math.atan2(y, x) * Constants.RAD_TO_DEG;

        // atan2 returns -180 to +180. Normalize to 0-360.
        // Example: -90 (West) becomes 270.
        // Normalize to 0-360 range. Monkey C mod doesn't work on floats,
        // so we use a manual wrap: add 360 to handle negatives, then subtract
        // 360 if the result is >= 360.
        var result = bearing + 360.0;
        if (result >= 360.0) {
            result = result - 360.0;
        }
        if (result >= 360.0) {
            result = result - 360.0;
        }
        return result;
    }

    /**
     * destinationPoint() — Calculate where you end up walking from a point.
     *
     * Given a starting GPS position, a compass bearing, and a distance,
     * calculate the GPS coordinates of the destination. This is the
     * inverse of haversineDistance + calculateBearing.
     *
     * Used by the Downed Bird Locator: "I'm standing here, the bird fell
     * in THAT direction, about 20 yards away — where is it?"
     *
     * @param lat — starting latitude, in DEGREES
     * @param lon — starting longitude, in DEGREES
     * @param bearing — compass bearing to travel, in DEGREES (0-360)
     * @param distance — distance to travel, in METERS
     * @return Array [latitude, longitude] of the destination, in DEGREES
     */
    function destinationPoint(lat as Double, lon as Double,
                               bearing as Double, distance as Double) as Array<Double> {
        // Convert to radians
        var latRad = lat * Constants.DEG_TO_RAD;
        var lonRad = lon * Constants.DEG_TO_RAD;
        var bearRad = bearing * Constants.DEG_TO_RAD;

        // Angular distance = distance / Earth's radius
        var angDist = distance / Constants.EARTH_RADIUS_M;

        // Destination latitude:
        // lat2 = asin(sin(lat1)*cos(d/R) + cos(lat1)*sin(d/R)*cos(bearing))
        var lat2Rad = Math.asin(
            Math.sin(latRad) * Math.cos(angDist) +
            Math.cos(latRad) * Math.sin(angDist) * Math.cos(bearRad)
        );

        // Destination longitude:
        // lon2 = lon1 + atan2(sin(bearing)*sin(d/R)*cos(lat1),
        //                     cos(d/R) - sin(lat1)*sin(lat2))
        var lon2Rad = lonRad + Math.atan2(
            Math.sin(bearRad) * Math.sin(angDist) * Math.cos(latRad),
            Math.cos(angDist) - Math.sin(latRad) * Math.sin(lat2Rad)
        );

        // Convert back to degrees and return as array
        return [lat2Rad * Constants.RAD_TO_DEG, lon2Rad * Constants.RAD_TO_DEG] as Array<Double>;
    }

    /**
     * toCardinal() — Convert a compass bearing in degrees to a cardinal direction string.
     *
     * Divides the compass into 8 sectors of 45 degrees each:
     *   N (337.5-22.5), NE (22.5-67.5), E (67.5-112.5), etc.
     *
     * @param degrees — compass bearing (0-360)
     * @return cardinal direction string: "N", "NE", "E", "SE", "S", "SW", "W", or "NW"
     */
    function toCardinal(degrees as Double) as String {
        // Normalize to 0-360 range (handles negative values or >360)
        var normalized = degrees + 360.0;
        while (normalized >= 360.0) {
            normalized = normalized - 360.0;
        }
        while (normalized < 0.0) {
            normalized = normalized + 360.0;
        }

        // Each sector is 45 degrees wide, centered on the cardinal direction.
        // Adding 22.5 shifts the boundaries so 0 degrees is center of "N"
        // rather than the boundary between "NW" and "N".
        if (normalized >= 337.5 || normalized < 22.5)  { return "N"; }
        if (normalized < 67.5)  { return "NE"; }
        if (normalized < 112.5) { return "E"; }
        if (normalized < 157.5) { return "SE"; }
        if (normalized < 202.5) { return "S"; }
        if (normalized < 247.5) { return "SW"; }
        if (normalized < 292.5) { return "W"; }
        return "NW";
    }

    /**
     * metersToYards() — Convert meters to yards.
     *
     * @param meters — distance in meters
     * @return distance in yards
     */
    function metersToYards(meters as Double) as Double {
        return meters * Constants.METERS_TO_YARDS;
    }

    /**
     * yardsToMeters() — Convert yards to meters.
     *
     * @param yards — distance in yards
     * @return distance in meters
     */
    function yardsToMeters(yards as Double) as Double {
        return yards * Constants.YARDS_TO_METERS;
    }

    /**
     * formatDistance() — Format a distance for display with appropriate units.
     *
     * Reads the user's unit preference from settings and formats
     * the distance accordingly. Always takes meters as input
     * (since that's what haversineDistance returns).
     *
     * @param meters — distance in meters
     * @return formatted string like "45 yd" or "41 m"
     */
    function formatDistance(meters as Double) as String {
        // Delegate to the null-safe Constants.isMetric() rather than reading
        // Application.Properties directly — avoids NullReferenceException on
        // first launch before the property has been written by Garmin Connect Mobile.
        if (Constants.isMetric()) {
            // Metric
            return meters.format("%d") + " m";
        } else {
            // Imperial (default)
            var yards = metersToYards(meters);
            return yards.format("%d") + " yd";
        }
    }
}
