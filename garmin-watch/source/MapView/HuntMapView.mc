import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Position;
import Toybox.Application;
import Toybox.Timer;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

/**
 * HuntMapView — Phase 3: Map view showing the hunt on a real Garmin map.
 *
 * Displays the device's built-in topo/satellite map overlaid with:
 *   - User's current position (built-in from MapTrackView)
 *   - Flush waypoints as pin markers with species name labels
 *   - Downed bird markers as pin markers with "BIRD" labels
 *   - Breadcrumb trail showing the hunter's walking path (orange polyline)
 *   - Auto-zoom to fit all markers, or manual zoom via UP/DOWN buttons
 *
 * HOW IT WORKS:
 *   MapTrackView is a special View that renders the Garmin map engine.
 *   It automatically shows the device's current GPS position on the map.
 *   We extend it and add our hunting markers on top using the MapMarker API.
 *   The map handles all rendering, tile loading, and coordinate projection.
 *   We just tell it what area to show (setMapVisibleArea) and what markers
 *   to display (setMapMarker).
 *
 * ZOOM MODES:
 *   - Auto-zoom (default): Calculates a bounding box that includes ALL
 *     active markers and the current position, then fits everything in view.
 *   - Manual zoom: UP/DOWN buttons zoom in/out centered on current position.
 *     SELECT toggles back to auto-zoom.
 *
 * PERFORMANCE:
 *   - Markers update every 2 seconds (not every frame) to save battery
 *   - Waypoints are cached and only reloaded from Object Store every 10 seconds
 *   - Breadcrumb positions are read from the app's in-memory array (no I/O)
 */
class HuntMapView extends WatchUi.MapTrackView {

    // Timer for periodic map updates (markers, zoom, breadcrumb trail).
    // 2-second interval balances responsiveness with battery savings.
    var _updateTimer as Timer.Timer?;

    // Current manual zoom level (1 = closest, 7 = farthest).
    // Only used when _isAutoZoom is false.
    var _zoomLevel as Number = 4;

    // Whether auto-zoom is active.
    // Auto-zoom calculates a bounding box to fit all markers in view.
    // Manual zoom centers on the current position at a fixed zoom level.
    var _isAutoZoom as Boolean = true;

    // Cached waypoint data — avoids loading from Object Store every 2 seconds.
    // Refreshed every 10 seconds or when a new waypoint is added.
    var _cachedWaypoints as Array<Waypoint>?;

    // Unix timestamp of last waypoint cache refresh
    var _lastWaypointLoad as Number = 0;

    /**
     * Constructor — initializes the map view.
     * MapTrackView handles all the heavy lifting of map rendering.
     */
    function initialize() {
        MapTrackView.initialize();
    }

    /**
     * onShow() — Configure the map when this view appears.
     *
     * Sets map mode to PREVIEW (allows custom overlays on top),
     * restricts the map rendering area to leave room for header/footer,
     * loads initial data, and starts the update timer.
     */
    function onShow() as Void {
        // Preview mode lets us draw custom overlay UI on top of the map.
        // Browse mode would give native pan/zoom but blocks our overlays.
        setMapMode(WatchUi.MAP_MODE_PREVIEW);

        // Restrict map rendering to leave room for header and footer overlays.
        // On a 454x454 round screen, the map draws between y=30 and y=429.
        var settings = System.getDeviceSettings();
        setScreenVisibleArea(0, 30, settings.screenWidth, settings.screenHeight - 25);

        // Load waypoints and set up initial markers
        refreshWaypoints();
        updateMapContent();

        // Start the 2-second update timer to refresh markers and zoom
        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onMapUpdate), 2000, true);
    }

    /**
     * onMapUpdate() — Timer callback for periodic map content refresh.
     *
     * Re-reads marker data and recalculates zoom every 2 seconds.
     * This keeps the map current as the hunter walks and adds new markers.
     */
    function onMapUpdate() as Void {
        updateMapContent();
        WatchUi.requestUpdate();
    }

    /**
     * updateMapContent() — Refresh all map content (markers, trail, zoom).
     *
     * Called both on initial display and every 2 seconds by the timer.
     * Orchestrates the three map content updates:
     *   1. Markers (waypoints + bird markers)
     *   2. Breadcrumb trail polyline
     *   3. Zoom level (auto or manual)
     */
    function updateMapContent() as Void {
        updateMarkers();
        updateBreadcrumb();
        if (_isAutoZoom) {
            autoZoom();
        }
    }

    /**
     * refreshWaypoints() — Reload waypoints from Object Store if stale.
     *
     * Only loads fresh data if more than 10 seconds have passed since
     * the last load. Object Store reads are relatively expensive, so
     * we cache the data to avoid doing it every 2-second update cycle.
     */
    function refreshWaypoints() as Void {
        var now = Time.now().value();
        if (now - _lastWaypointLoad > 10) {
            var app = Application.getApp() as UplandHunterApp;
            var session = app.getHuntSession();
            _cachedWaypoints = WaypointManager.getSessionWaypoints(session.getStartTime());
            _lastWaypointLoad = now;
        }
    }

    /**
     * updateMarkers() — Build and apply all map markers.
     *
     * Creates MapMarker objects for three types of data:
     *   1. Flush waypoints (from current session) — labeled with species name
     *   2. Downed bird markers (active bird searches) — labeled "BIRD"
     *   3. Dog positions (from the live ANT+ dog tracker) — labeled with dog name
     *
     * Each marker uses the built-in MAP_MARKER_ICON_PIN icon.
     * Custom bitmap icons could be added in Phase 5 for visual distinction.
     *
     * NOTE: setMapMarker() replaces all previous markers every time.
     * This is by design — the marker list is rebuilt from scratch each cycle.
     */
    function updateMarkers() as Void {
        var markers = [] as Array<WatchUi.MapMarker>;

        // Reload waypoints periodically to catch newly added ones
        refreshWaypoints();

        // --- Flush waypoint markers ---
        // These show where the hunter marked bird flushes during this session.
        if (_cachedWaypoints != null) {
            var wps = _cachedWaypoints as Array<Waypoint>;
            for (var i = 0; i < wps.size(); i++) {
                var wp = wps[i];
                var loc = new Position.Location({
                    :latitude => wp.latitude.toFloat(),
                    :longitude => wp.longitude.toFloat(),
                    :format => :degrees
                });
                var marker = new WatchUi.MapMarker(loc);
                marker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
                marker.setLabel(Constants.getSpeciesName(wp.species));
                markers.add(marker);
            }
        }

        // --- Downed bird markers ---
        // These show where downed birds are estimated to be (from Phase 2).
        // The hunter is actively searching for these birds.
        var birdMarkers = BirdMarkerManager.getMarkers();
        for (var i = 0; i < birdMarkers.size(); i++) {
            var bm = birdMarkers[i];
            var loc = new Position.Location({
                :latitude => bm.targetLat.toFloat(),
                :longitude => bm.targetLon.toFloat(),
                :format => :degrees
            });
            var marker = new WatchUi.MapMarker(loc);
            marker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
            marker.setLabel("BIRD");
            markers.add(marker);
        }

        // --- Dog position markers ---
        // Show dogs on the map using their distance/direction from the hunter.
        // Since dogs don't have GPS coordinates directly, we calculate their
        // estimated position from the hunter's position + dog distance + direction.
        var app2 = Application.getApp() as UplandHunterApp;
        if (app2._lastPosition != null && app2._lastPosition.position != null &&
            app2._dogTracker.getConnectionState() == Constants.ANT_STATE_CONNECTED) {
            var hunterCoords = app2._lastPosition.position.toDegrees();
            var hunterLat = hunterCoords[0] as Double;
            var hunterLon = hunterCoords[1] as Double;
            var dogs = app2._dogTracker.getDogs();

            for (var d = 0; d < dogs.size(); d++) {
                var dog = dogs[d] as DogData;
                // Skip dogs with no signal
                if (dog.status == Constants.DOG_STATUS_COMM_LOST) {
                    continue;
                }

                // Calculate dog's GPS position from hunter + distance + direction
                var distMeters = dog.distanceYards.toDouble() * Constants.YARDS_TO_METERS;
                var dogPos = CoordinateMath.destinationPoint(
                    hunterLat, hunterLon, dog.direction, distMeters
                );

                var dogLoc = new Position.Location({
                    :latitude => (dogPos[0] as Double).toFloat(),
                    :longitude => (dogPos[1] as Double).toFloat(),
                    :format => :degrees
                });
                var dogMarker = new WatchUi.MapMarker(dogLoc);
                dogMarker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
                dogMarker.setLabel(dog.name);
                markers.add(dogMarker);
            }
        }

        // Apply markers to the map (replaces any previously set markers)
        if (markers.size() > 0) {
            setMapMarker(markers);
        } else {
            // Clear old markers if we have none
            clear();
        }
    }

    /**
     * autoZoom() — Calculate a bounding box that fits all markers in view.
     *
     * Algorithm:
     *   1. Collect lat/lon of current position, all waypoints, all bird markers
     *   2. Find the min/max latitude and longitude (the bounding box)
     *   3. Add padding so markers aren't at the very edge
     *   4. Call setMapVisibleArea() with the padded bounding box
     *
     * This ensures the hunter can always see all their markers, bird
     * locations, and their own position on one screen without scrolling.
     */
    function autoZoom() as Void {
        var app = Application.getApp() as UplandHunterApp;

        // Track the extremes of our bounding box
        var minLat = 90.0d;
        var maxLat = -90.0d;
        var minLon = 180.0d;
        var maxLon = -180.0d;
        var hasPoints = false;

        // Include the hunter's current GPS position
        if (app._lastPosition != null && app._lastPosition.position != null) {
            var coords = app._lastPosition.position.toDegrees();
            var lat = coords[0] as Double;
            var lon = coords[1] as Double;
            if (lat < minLat) { minLat = lat; }
            if (lat > maxLat) { maxLat = lat; }
            if (lon < minLon) { minLon = lon; }
            if (lon > maxLon) { maxLon = lon; }
            hasPoints = true;
        }

        // Include all flush waypoints
        if (_cachedWaypoints != null) {
            var wps = _cachedWaypoints as Array<Waypoint>;
            for (var i = 0; i < wps.size(); i++) {
                var wp = wps[i];
                if (wp.latitude < minLat) { minLat = wp.latitude; }
                if (wp.latitude > maxLat) { maxLat = wp.latitude; }
                if (wp.longitude < minLon) { minLon = wp.longitude; }
                if (wp.longitude > maxLon) { maxLon = wp.longitude; }
                hasPoints = true;
            }
        }

        // Include all downed bird markers
        var birdMarkers = BirdMarkerManager.getMarkers();
        for (var i = 0; i < birdMarkers.size(); i++) {
            var bm = birdMarkers[i];
            if (bm.targetLat < minLat) { minLat = bm.targetLat; }
            if (bm.targetLat > maxLat) { maxLat = bm.targetLat; }
            if (bm.targetLon < minLon) { minLon = bm.targetLon; }
            if (bm.targetLon > maxLon) { maxLon = bm.targetLon; }
            hasPoints = true;
        }

        // No markers and no GPS — can't calculate a bounding box
        if (!hasPoints) {
            return;
        }

        // Calculate padding based on the spread of markers.
        // If all points are clustered (e.g., just current position), use a
        // minimum padding of 0.005° (~550m) so the map isn't overly zoomed in.
        // For wider spreads, add 30% padding so markers aren't at the edge.
        var latRange = maxLat - minLat;
        var lonRange = maxLon - minLon;
        var padding = 0.005d; // Minimum ~550m view

        if (latRange * 0.3d > padding) {
            padding = latRange * 0.3d;
        }
        if (lonRange * 0.3d > padding) {
            padding = lonRange * 0.3d;
        }

        // Apply padding to the bounding box
        minLat = minLat - padding;
        maxLat = maxLat + padding;
        minLon = minLon - padding;
        maxLon = maxLon + padding;

        // Set the map to show this geographic area.
        // topLeft = northwest corner (high lat, low lon)
        // bottomRight = southeast corner (low lat, high lon)
        var topLeft = new Position.Location({
            :latitude => maxLat.toFloat(),
            :longitude => minLon.toFloat(),
            :format => :degrees
        });
        var bottomRight = new Position.Location({
            :latitude => minLat.toFloat(),
            :longitude => maxLon.toFloat(),
            :format => :degrees
        });

        setMapVisibleArea(topLeft, bottomRight);
    }

    /**
     * applyManualZoom() — Zoom to a fixed area centered on current position.
     *
     * Creates a bounding box of a specific size (based on zoom level)
     * centered on the hunter's GPS position. Used when the hunter
     * manually adjusts zoom with UP/DOWN buttons.
     */
    function applyManualZoom() as Void {
        var app = Application.getApp() as UplandHunterApp;
        if (app._lastPosition == null || app._lastPosition.position == null) {
            return;
        }

        var coords = app._lastPosition.position.toDegrees();
        var lat = coords[0] as Double;
        var lon = coords[1] as Double;

        // Get the degree range for the current zoom level
        var range = getZoomRange();

        var topLeft = new Position.Location({
            :latitude => (lat + range).toFloat(),
            :longitude => (lon - range).toFloat(),
            :format => :degrees
        });
        var bottomRight = new Position.Location({
            :latitude => (lat - range).toFloat(),
            :longitude => (lon + range).toFloat(),
            :format => :degrees
        });

        setMapVisibleArea(topLeft, bottomRight);
    }

    /**
     * getZoomRange() — Convert zoom level to a degree range.
     *
     * Returns how many degrees of lat/lon to show in each direction
     * from the center point. Each level roughly doubles the visible area.
     *
     * Approximate real-world distances (at mid-latitudes):
     *   Level 1: ~55m  (bird search)
     *   Level 2: ~110m (field view)
     *   Level 3: ~330m (nearby area)
     *   Level 4: ~550m (default, property-sized view)
     *   Level 5: ~1.1km (farm-scale view)
     *   Level 6: ~3.3km (section view)
     *   Level 7: ~11km (ranch/region view)
     */
    function getZoomRange() as Double {
        switch (_zoomLevel) {
            case 1: return 0.0005d;
            case 2: return 0.001d;
            case 3: return 0.003d;
            case 4: return 0.005d;
            case 5: return 0.01d;
            case 6: return 0.03d;
            case 7: return 0.1d;
            default: return 0.005d;
        }
    }

    /**
     * updateBreadcrumb() — Build the breadcrumb trail polyline.
     *
     * Reads the GPS position history stored in UplandHunterApp and creates
     * a MapPolyline showing the hunter's walking path on the map.
     * The trail is orange (our primary color) and 3px wide.
     *
     * Positions are sampled every 5 seconds during an active hunt,
     * stored as [lat, lon] arrays in the app's _breadcrumbPositions.
     */
    function updateBreadcrumb() as Void {
        var app = Application.getApp() as UplandHunterApp;
        var positions = app._breadcrumbPositions;

        // Need at least 2 points to draw a line
        if (positions.size() < 2) {
            return;
        }

        // Create a polyline from the stored GPS positions
        var polyline = new WatchUi.MapPolyline();
        polyline.setColor(Constants.COLOR_PRIMARY);  // Orange trail
        polyline.setWidth(3);

        // Add each position as a polyline vertex
        for (var i = 0; i < positions.size(); i++) {
            var pos = positions[i] as Array;
            var lat = pos[0] as Double;
            var lon = pos[1] as Double;
            var loc = new Position.Location({
                :latitude => lat.toFloat(),
                :longitude => lon.toFloat(),
                :format => :degrees
            });
            polyline.addLocation(loc);
        }

        // Apply the polyline to the map (replaces any previous polyline)
        setPolyline(polyline);
    }

    /**
     * onUpdate() — Render the map with custom overlay UI.
     *
     * First calls the parent MapTrackView.onUpdate() to render the map,
     * then draws our custom header and footer on top. This layering
     * approach lets us show app-specific info without replacing the map.
     *
     * Layout:
     *   [Header] "HUNT MAP" title bar (orange on dark background)
     *   [Map]    Full map with markers and trail (rendered by MapTrackView)
     *   [Footer] Zoom mode indicator (AUTO or manual level)
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        // Render the map first — MapTrackView handles all tile rendering,
        // coordinate projection, and marker placement
        MapTrackView.onUpdate(dc);

        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // --- Header overlay ---
        // Dark bar at top with title — uses high contrast background
        dc.setColor(Constants.getBgColor(), Constants.getBgColor());
        dc.fillRectangle(0, 0, screenW, 30);
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 5, Graphics.FONT_XTINY,
            "HUNT MAP", Graphics.TEXT_JUSTIFY_CENTER);

        // --- Marker count badge ---
        // Shows how many markers are on the map (top-right corner)
        var markerCount = 0;
        if (_cachedWaypoints != null) {
            markerCount += (_cachedWaypoints as Array<Waypoint>).size();
        }
        markerCount += BirdMarkerManager.getMarkerCount();

        if (markerCount > 0) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(screenW - 40, 8, Graphics.FONT_XTINY,
                markerCount.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- Footer overlay ---
        // Shows current zoom mode (AUTO or manual level)
        dc.setColor(Constants.getBgColor(), Constants.getBgColor());
        dc.fillRectangle(0, screenH - 25, screenW, 25);
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);

        var zoomText = "ZOOM: ";
        if (_isAutoZoom) {
            zoomText += "AUTO";
        } else {
            zoomText += _zoomLevel.format("%d") + "/7";
        }
        dc.drawText(centerX, screenH - 23, Graphics.FONT_XTINY,
            zoomText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * zoomIn() — Increase zoom (show smaller area, more detail).
     *
     * Switches to manual zoom mode and decreases the zoom level number
     * (lower number = tighter zoom). Minimum is level 1 (~55m view).
     */
    function zoomIn() as Void {
        _isAutoZoom = false;
        if (_zoomLevel > 1) {
            _zoomLevel--;
        }
        applyManualZoom();
        WatchUi.requestUpdate();
    }

    /**
     * zoomOut() — Decrease zoom (show larger area, less detail).
     *
     * Switches to manual zoom mode and increases the zoom level number
     * (higher number = wider zoom). Maximum is level 7 (~11km view).
     */
    function zoomOut() as Void {
        _isAutoZoom = false;
        if (_zoomLevel < 7) {
            _zoomLevel++;
        }
        applyManualZoom();
        WatchUi.requestUpdate();
    }

    /**
     * toggleAutoZoom() — Switch between auto and manual zoom modes.
     *
     * When switching to auto-zoom, immediately recalculates the
     * bounding box to fit all markers. The hunter can press SELECT
     * to toggle between modes at any time.
     */
    function toggleAutoZoom() as Void {
        _isAutoZoom = !_isAutoZoom;
        if (_isAutoZoom) {
            _zoomLevel = 4;  // Reset manual zoom to default
            autoZoom();
        }
        WatchUi.requestUpdate();
    }

    /**
     * onHide() — Stop the update timer when leaving the map view.
     * Saves battery by not updating map content when it's not visible.
     */
    function onHide() as Void {
        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }
    }
}

/**
 * HuntMapDelegate — Input handler for the map view.
 *
 * Button mapping:
 *   UP:     Zoom in (more detail, smaller area)
 *   DOWN:   Zoom out (less detail, larger area)
 *   SELECT: Toggle between auto-zoom and manual zoom
 *   BACK:   Return to the main hunt screen (list view)
 *
 * Zoom behavior: UP/DOWN immediately switch to manual zoom mode.
 * SELECT toggles back to auto-zoom (fit all markers in view).
 */
class HuntMapDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Toggle auto/manual zoom mode.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }
        var view = WatchUi.getCurrentView()[0] as HuntMapView;
        view.toggleAutoZoom();
        return true;
    }

    /**
     * onNextPage() — DOWN button: Zoom out to see more area.
     */
    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as HuntMapView;
        view.zoomOut();
        return true;
    }

    /**
     * onPreviousPage() — UP button: Zoom in to see more detail.
     */
    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as HuntMapView;
        view.zoomIn();
        return true;
    }

    /**
     * onBack() — Return to the main hunt screen (list view).
     */
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
