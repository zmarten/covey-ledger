import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Position;
import Toybox.Math;
import Toybox.Application;
import Toybox.Timer;
import Toybox.Lang;

/**
 * NavigationView — Screen 3 of 3 in the Downed Bird Locator workflow.
 *
 * Guides the hunter to the downed bird with:
 *   - A large rotating arrow pointing toward the bird's estimated position
 *   - Real-time distance that updates as the hunter walks
 *   - Cardinal direction label (N, NE, E, etc.)
 *   - Two action buttons: RETRIEVED (removes marker) and BACK TO HUNT
 *
 * HOW THE ARROW WORKS:
 *   1. We know the bird's GPS coordinates (calculated in DistanceEntryView)
 *   2. We know the hunter's current GPS coordinates (from onPosition callback)
 *   3. We calculate the bearing from hunter → bird using calculateBearing()
 *   4. The arrow points in that bearing direction
 *   5. As the hunter walks, both distance and bearing update in real-time
 *
 * The arrow is "absolute" — it always points toward the bird regardless
 * of which direction the hunter is facing. This means the hunter can
 * follow the arrow like a compass needle toward the bird.
 *
 * NOTE: This does NOT use the compass/magnetometer for the arrow direction.
 * The arrow shows the GPS-based direction from current position to target.
 * Compass heading is used in BearingCaptureView, not here.
 */
class NavigationView extends WatchUi.View {

    // The bird marker we're navigating to
    var _marker as BirdMarker;

    // Current calculated distance to the bird (meters)
    var _distanceToTarget as Double = 0.0d;

    // Current calculated bearing to the bird (degrees, 0-360)
    var _bearingToTarget as Double = 0.0d;

    // Timer for updating navigation data
    var _updateTimer as Timer.Timer?;

    // Currently focused button: 0 = none, 1 = RETRIEVED, 2 = BACK TO HUNT
    var _focusedButton as Number = 0;

    /**
     * Constructor — receives the bird marker to navigate to.
     *
     * @param marker — the BirdMarker containing the target coordinates
     */
    function initialize(marker as BirdMarker) {
        View.initialize();
        _marker = marker;
    }

    /**
     * onShow() — Start the navigation update timer.
     *
     * Updates every 500ms for smooth distance/direction changes
     * as the hunter walks toward the bird.
     */
    function onShow() as Void {
        updateNavigation();

        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onNavUpdate), 500, true);
    }

    /**
     * onNavUpdate() — Timer callback to recalculate navigation data.
     *
     * Gets the latest GPS position and recalculates distance/bearing
     * from the hunter's current position to the bird marker.
     */
    function onNavUpdate() as Void {
        updateNavigation();
        WatchUi.requestUpdate();
    }

    /**
     * updateNavigation() — Recalculate distance and bearing to target.
     *
     * Reads the current GPS position from the app and uses haversine
     * distance and bearing formulas to compute navigation data.
     */
    function updateNavigation() as Void {
        var app = Application.getApp() as UplandHunterApp;

        if (app._lastPosition != null && app._lastPosition.position != null) {
            var coords = app._lastPosition.position.toDegrees();
            var currentLat = coords[0] as Double;
            var currentLon = coords[1] as Double;

            // Calculate distance from current position to bird
            _distanceToTarget = CoordinateMath.haversineDistance(
                currentLat, currentLon,
                _marker.targetLat, _marker.targetLon
            );

            // Calculate bearing from current position to bird
            _bearingToTarget = CoordinateMath.calculateBearing(
                currentLat, currentLon,
                _marker.targetLat, _marker.targetLon
            );
        }
    }

    /**
     * onUpdate() — Draw the navigation screen.
     *
     * Layout:
     *   - Header: "FIND BIRD" with marker number
     *   - Center: Large rotating arrow pointing to bird
     *   - Distance display (large, color-coded)
     *   - Cardinal direction
     *   - Bottom: RETRIEVED and BACK TO HUNT buttons
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;
        var centerY = screenH / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // --- Header ---
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 25, Graphics.FONT_SMALL,
            "FIND BIRD", Graphics.TEXT_JUSTIFY_CENTER);

        // --- Navigation Arrow ---
        // The arrow points from screen center toward the bird.
        // In screen coordinates: 0° (north) = up, 90° (east) = right.
        var bearingRad = Math.toRadians(_bearingToTarget);
        var arrowCenterY = centerY - 30;
        var arrowLength = 65;

        // Arrow tip
        var tipX = centerX + (arrowLength * Math.sin(bearingRad)).toNumber();
        var tipY = arrowCenterY - (arrowLength * Math.cos(bearingRad)).toNumber();

        // Arrow tail
        var tailLen = arrowLength * 0.35;
        var tailX = centerX - (tailLen * Math.sin(bearingRad)).toNumber();
        var tailY = arrowCenterY + (tailLen * Math.cos(bearingRad)).toNumber();

        // Draw arrow body
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        dc.drawLine(tailX, tailY, tipX, tipY);

        // Draw arrowhead — filled circle at the tip for simplicity.
        // fillPolygon has strict type requirements, so we use a circle instead.
        dc.fillCircle(tipX, tipY, 10);

        // Center dot
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, arrowCenterY, 4);
        dc.setPenWidth(1);

        // --- Distance display ---
        // Uses the user's preferred units (yards or meters).
        // Color coding works the same regardless of unit system — thresholds
        // are in yards internally, so we convert to yards for comparison.
        var distYards = CoordinateMath.metersToYards(_distanceToTarget);
        var distColor = Constants.COLOR_SUCCESS; // Green when close
        if (distYards > Constants.DISTANCE_FAR_THRESHOLD.toDouble()) {
            distColor = Constants.COLOR_ALERT;  // Red when far
        } else if (distYards > Constants.DISTANCE_CLOSE_THRESHOLD.toDouble()) {
            distColor = Constants.COLOR_WARNING; // Yellow when medium
        }

        dc.setColor(distColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY + 45, Graphics.FONT_LARGE,
            Constants.formatNavigationDistance(_distanceToTarget),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Cardinal direction
        var cardinal = CoordinateMath.toCardinal(_bearingToTarget);
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY + 85, Graphics.FONT_SMALL,
            cardinal, Graphics.TEXT_JUSTIFY_CENTER);

        // --- Action buttons ---
        var btnWidth = (screenW - 130) / 2;
        var btnHeight = 45;
        var btnY = screenH - 80;
        var gap = 10;

        // RETRIEVED button (left, green)
        var retX = centerX - btnWidth - gap / 2;
        if (_focusedButton == 1) {
            dc.setColor(Constants.COLOR_SUCCESS, Constants.COLOR_SUCCESS);
            dc.fillRoundedRectangle(retX, btnY, btnWidth, btnHeight, 6);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(retX, btnY, btnWidth, btnHeight, 6);
        }
        dc.drawText(retX + btnWidth / 2, btnY + 10, Graphics.FONT_XTINY,
            "GOT IT", Graphics.TEXT_JUSTIFY_CENTER);

        // BACK TO HUNT button (right, muted)
        var backX = centerX + gap / 2;
        if (_focusedButton == 2) {
            dc.setColor(Constants.COLOR_MUTED, Constants.COLOR_MUTED);
            dc.fillRoundedRectangle(backX, btnY, btnWidth, btnHeight, 6);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(backX, btnY, btnWidth, btnHeight, 6);
        }
        dc.drawText(backX + btnWidth / 2, btnY + 10, Graphics.FONT_XTINY,
            "HUNT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * onHide() — Stop the update timer when leaving this view.
     */
    function onHide() as Void {
        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }
    }
}

/**
 * NavigationDelegate — Input handler for the navigation screen.
 *
 * SELECT activates the focused button.
 * UP/DOWN switches focus between buttons.
 * BACK returns to hunt (keeps marker active).
 */
class NavigationDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Handle button activation.
     *
     * No button focused: focus RETRIEVED.
     * RETRIEVED: remove marker and pop all bird locator views.
     * BACK TO HUNT: keep marker active and pop all bird locator views.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as NavigationView;

        if (view._focusedButton == 0) {
            // Nothing focused — focus the first button
            view._focusedButton = 1;
            WatchUi.requestUpdate();
        } else if (view._focusedButton == 1) {
            // RETRIEVED — bird is found! Remove marker and go back to hunt.
            BirdMarkerManager.removeMarker(view._marker.id);
            popToHunt();
        } else if (view._focusedButton == 2) {
            // BACK TO HUNT — keep marker active for later navigation.
            popToHunt();
        }
        return true;
    }

    /**
     * popToHunt() — Pop all bird locator views to return to the main hunt screen.
     *
     * The bird locator workflow pushes 3 views:
     *   BearingCapture → DistanceEntry → Navigation
     * We need to pop all 3 to get back to the main view (or BirdsDownView).
     */
    function popToHunt() as Void {
        // Pop Navigation
        WatchUi.popView(WatchUi.SLIDE_DOWN);

        // Schedule pops for DistanceEntry and BearingCapture
        var timer1 = new Timer.Timer();
        timer1.start(method(:popMore1), 50, false);
    }

    function popMore1() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        var timer2 = new Timer.Timer();
        timer2.start(method(:popMore2), 50, false);
    }

    function popMore2() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as NavigationView;
        if (view._focusedButton < 2) {
            view._focusedButton++;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as NavigationView;
        if (view._focusedButton > 0) {
            view._focusedButton--;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        // BACK keeps marker active and returns to previous screen
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
