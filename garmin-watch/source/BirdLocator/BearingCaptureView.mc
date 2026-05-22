import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Sensor;
import Toybox.Math;
import Toybox.Lang;
import Toybox.System;

/**
 * BearingCaptureView — Screen 1 of 3 in the Downed Bird Locator workflow.
 *
 * The hunter physically points their watch arm toward where the bird fell.
 * This screen shows a live compass with a rotating arrow and the current
 * heading in degrees + cardinal direction. When the hunter presses SELECT,
 * we capture that compass bearing.
 *
 * HOW IT WORKS:
 *   1. The magnetometer (compass sensor) gives us the watch's heading
 *   2. We display a rotating compass arrow pointing in the direction the watch faces
 *   3. The hunter aims their arm at the downed bird
 *   4. SELECT captures the current heading — that's the bearing to the bird
 *
 * The bearing + distance (entered on the next screen) let us calculate
 * the bird's GPS coordinates using the destinationPoint() formula.
 *
 * SENSOR NOTE: The magnetometer can be inaccurate near metal objects
 * (guns, trucks, belt buckles). We show the heading but can't fix
 * hardware limitations. A calibration prompt could be added in Phase 5.
 */
class BearingCaptureView extends WatchUi.View {

    // Current compass heading from the magnetometer (0-360 degrees).
    // Updated every time the sensor fires. 0 = North.
    var _currentHeading as Float = 0.0f;

    // Whether we're receiving valid compass data
    var _hasCompass as Boolean = false;

    // The captured GPS position at the time this view was created.
    // Passed from the flush workflow (BirdsDownView).
    var _capturedLat as Double;
    var _capturedLon as Double;

    /**
     * Constructor — starts the compass sensor.
     *
     * @param lat — current GPS latitude (where the hunter is standing)
     * @param lon — current GPS longitude
     */
    function initialize(lat as Double, lon as Double) {
        View.initialize();
        _capturedLat = lat;
        _capturedLon = lon;
    }

    /**
     * onShow() — Enable the magnetometer sensor when this view appears.
     *
     * We register a sensor listener that fires rapidly (every ~100ms)
     * to give smooth compass needle movement. The listener calls
     * onSensorData() with the latest heading.
     */
    function onShow() as Void {
        // Enable sensor events to receive compass heading data.
        // The magnetometer doesn't need to be explicitly enabled via
        // setEnabledSensors() — it's always available. We just register
        // a callback to receive periodic sensor updates including heading.
        Sensor.enableSensorEvents(method(:onSensorData));
    }

    /**
     * onSensorData() — Callback when new compass data arrives.
     *
     * The system calls this with a SensorInfo object containing
     * the current magnetic heading. We convert from radians to degrees
     * and store it for the display to use.
     *
     * @param sensorInfo — the latest sensor readings
     */
    function onSensorData(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo.heading != null) {
            // heading is in radians, convert to degrees (0-360)
            _currentHeading = Math.toDegrees(sensorInfo.heading).toFloat();

            // Normalize to 0-360 range
            if (_currentHeading < 0.0f) {
                _currentHeading += 360.0f;
            }
            _hasCompass = true;
        } else {
            _hasCompass = false;
        }

        // Redraw with the new heading
        WatchUi.requestUpdate();
    }

    /**
     * onUpdate() — Draw the compass bearing capture screen.
     *
     * Layout:
     *   - "POINT TOWARD BIRD" instruction at top
     *   - Large rotating compass arrow in the center
     *   - Current heading in degrees (e.g., "247°")
     *   - Cardinal direction (e.g., "WSW")
     *   - "Press SELECT to capture" at bottom
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;
        var centerY = screenH / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // --- Header instruction ---
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 30, Graphics.FONT_SMALL,
            "POINT TOWARD", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 55, Graphics.FONT_SMALL,
            "BIRD", Graphics.TEXT_JUSTIFY_CENTER);

        if (_hasCompass) {
            // --- Draw compass arrow ---
            // The arrow points in the direction the watch is facing.
            // Convert heading to radians for sin/cos calculations.
            var headingRad = Math.toRadians(_currentHeading);

            // Arrow center point — slightly above screen center
            var arrowCenterY = centerY - 10;
            var arrowLength = 70;

            // Calculate arrow tip position (pointing "up" = direction watch faces)
            // In screen coordinates, up is negative Y.
            // The arrow rotates based on heading: 0° = up (north), 90° = right (east)
            var tipX = centerX + (arrowLength * Math.sin(headingRad)).toNumber();
            var tipY = arrowCenterY - (arrowLength * Math.cos(headingRad)).toNumber();

            // Arrow tail (opposite direction)
            var tailX = centerX - (arrowLength * 0.4 * Math.sin(headingRad)).toNumber();
            var tailY = arrowCenterY + (arrowLength * 0.4 * Math.cos(headingRad)).toNumber();

            // Draw the arrow line
            dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawLine(tailX, tailY, tipX, tipY);

            // Draw arrowhead — a small filled circle at the tip
            dc.fillCircle(tipX, tipY, 8);

            // Draw center dot
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, arrowCenterY, 5);

            // Reset pen width
            dc.setPenWidth(1);

            // --- Heading in degrees ---
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY + 55, Graphics.FONT_LARGE,
                _currentHeading.format("%d") + "\u00B0",
                Graphics.TEXT_JUSTIFY_CENTER);

            // --- Cardinal direction ---
            var cardinal = CoordinateMath.toCardinal(_currentHeading.toDouble());
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY + 95, Graphics.FONT_MEDIUM,
                cardinal, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // No compass data — show calibration message
            dc.setColor(Constants.COLOR_WARNING, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY, Graphics.FONT_SMALL,
                "Calibrating...", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY + 30, Graphics.FONT_XTINY,
                "Rotate wrist in a figure-8", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- Bottom hint ---
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 40, Graphics.FONT_XTINY,
            "SELECT: Capture bearing", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * onHide() — Disable compass sensor when leaving this view.
     * Saves battery by not polling the magnetometer needlessly.
     */
    function onHide() as Void {
        Sensor.enableSensorEvents(null);
    }

    /**
     * getCapturedHeading() — Return the current heading for capture.
     */
    function getCapturedHeading() as Float {
        return _currentHeading;
    }
}

/**
 * BearingCaptureDelegate — Input handler for bearing capture.
 *
 * SELECT captures the bearing and advances to distance entry.
 * BACK cancels and returns to the previous screen.
 */
class BearingCaptureDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Capture the current compass bearing and advance.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as BearingCaptureView;

        // Only capture if we have valid compass data
        if (!view._hasCompass) {
            return true;
        }

        var bearing = view.getCapturedHeading();

        // Advance to the distance entry screen, passing bearing and position
        WatchUi.pushView(
            new DistanceEntryView(
                bearing.toDouble(),
                view._capturedLat,
                view._capturedLon
            ),
            new DistanceEntryDelegate(),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
