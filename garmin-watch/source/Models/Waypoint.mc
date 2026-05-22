import Toybox.Lang;

/**
 * Waypoint — Data model for a single flush event.
 *
 * A Waypoint represents one moment during a hunt when birds flushed.
 * It captures everything about that event: where, when, what species,
 * how many, shot result, and birds downed.
 *
 * WHY A CLASS (not a Dictionary): Classes give us type safety, named
 * properties, and methods. Dictionaries are flexible but easy to
 * mistype keys. With a class, the compiler catches mistakes.
 *
 * MEMORY: Each Waypoint uses about 100 bytes of RAM. With 500 max
 * waypoints, that's ~50KB. Connect IQ apps typically get 64-128KB,
 * so we need to be conscious about memory.
 */
class Waypoint {

    // GPS location where the flush occurred (in degrees)
    var latitude as Double;
    var longitude as Double;

    // Unix timestamp of when the flush happened
    var timestamp as Number;

    // Species enum value (Constants.SPECIES_*)
    var species as Number;

    // How many birds flushed
    var quantityFlushed as Number;

    // How many birds went down (0 if missed or no shot)
    var birdsDown as Number;

    // Shot result enum (Constants.SHOT_HIT, SHOT_MISSED, SHOT_NO_SHOT)
    var shotResult as Number;

    // Covey size — only for quail/partridge. null if not applicable.
    var coveySize as Number?;

    // Whether a dog was on point when this flush happened.
    // Set to true if any dog's status was ON_POINT at flush time.
    var dogOnPoint as Boolean;

    // Name of the dog that was on point (null if no dog or unknown)
    var dogName as String?;

    // Unique ID for this waypoint — used for Object Store key.
    // Generated from timestamp to ensure uniqueness.
    var id as Number;

    /**
     * Constructor — create a new waypoint with all required data.
     *
     * @param lat — latitude in degrees
     * @param lon — longitude in degrees
     * @param time — Unix timestamp
     * @param spec — species enum value
     * @param flushed — number of birds flushed
     * @param down — number of birds downed
     * @param shot — shot result enum
     */
    function initialize(lat as Double, lon as Double, time as Number,
                         spec as Number, flushed as Number, down as Number,
                         shot as Number) {
        latitude = lat;
        longitude = lon;
        timestamp = time;
        species = spec;
        quantityFlushed = flushed;
        birdsDown = down;
        shotResult = shot;
        coveySize = null;
        dogOnPoint = false;
        dogName = null;
        // Use timestamp as ID — unique enough for our purposes since
        // debouncing prevents two waypoints in the same second
        id = time;
    }

    /**
     * toDictionary() — Serialize this waypoint to a Dictionary for Object Store.
     *
     * The Object Store API requires data to be serializable types
     * (dictionaries, arrays, strings, numbers, booleans). We can't
     * store class instances directly, so we convert to a dictionary.
     *
     * @return Dictionary representation of this waypoint
     */
    function toDictionary() as Dictionary {
        return {
            "id" => id,
            "lat" => latitude,
            "lon" => longitude,
            "time" => timestamp,
            "species" => species,
            "flushed" => quantityFlushed,
            "down" => birdsDown,
            "shot" => shotResult,
            "covey" => coveySize,
            "dogPt" => dogOnPoint,
            "dogNm" => dogName
        };
    }

    /**
     * fromDictionary() — Deserialize a waypoint from an Object Store dictionary.
     *
     * Factory method that creates a Waypoint from a stored dictionary.
     * Used when loading waypoints back from persistent storage.
     *
     * @param dict — the stored dictionary
     * @return a new Waypoint instance, or null if the dictionary is invalid
     */
    static function fromDictionary(dict as Dictionary) as Waypoint? {
        // Validate that required keys exist
        if (dict == null ||
            !dict.hasKey("lat") || !dict.hasKey("lon") ||
            !dict.hasKey("time") || !dict.hasKey("species")) {
            return null;
        }

        var wp = new Waypoint(
            dict["lat"] as Double,
            dict["lon"] as Double,
            dict["time"] as Number,
            dict["species"] as Number,
            dict.hasKey("flushed") ? dict["flushed"] as Number : 1,
            dict.hasKey("down") ? dict["down"] as Number : 0,
            dict.hasKey("shot") ? dict["shot"] as Number : Constants.SHOT_NO_SHOT
        );

        // Restore optional fields
        if (dict.hasKey("covey") && dict["covey"] != null) {
            wp.coveySize = dict["covey"] as Number;
        }
        if (dict.hasKey("dogPt")) {
            wp.dogOnPoint = dict["dogPt"] as Boolean;
        }
        if (dict.hasKey("dogNm") && dict["dogNm"] != null) {
            wp.dogName = dict["dogNm"] as String;
        }
        if (dict.hasKey("id")) {
            wp.id = dict["id"] as Number;
        }

        return wp;
    }
}
