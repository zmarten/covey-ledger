import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

/**
 * DistanceEntryView — Screen 2 of 3 in the Downed Bird Locator workflow.
 *
 * "How far away did the bird fall?"
 *
 * Shows a large distance number with UP/DOWN to adjust by 5-yard increments.
 * Also has quick-select buttons for common distances (10, 20, 30, 40 yards).
 * Default is 15 yards — a typical distance for an upland bird drop.
 *
 * The bearing (from BearingCaptureView) + distance entered here =
 * everything we need to calculate the bird's GPS position using
 * the destinationPoint() formula in CoordinateMath.
 *
 * FLOW: BearingCapture → [DistanceEntry] → Navigation
 */
class DistanceEntryView extends WatchUi.View {

    // Bearing captured on the previous screen (degrees, 0-360)
    var _bearing as Double;

    // GPS position where the hunter was standing when marking the bird
    var _capturedLat as Double;
    var _capturedLon as Double;

    // Current distance value in yards
    var _distanceYards as Number = 15;

    // Quick-select distance options (in yards)
    // These are common bird-drop distances in upland hunting
    var _quickDistances as Array<Number> = [10, 20, 30, 40] as Array<Number>;

    // Currently focused UI element:
    // 0 = distance counter (UP/DOWN adjusts value)
    // 1-4 = quick-select buttons
    // 5 = NEXT button
    var _focusedElement as Number = 0;

    /**
     * Constructor — receives bearing and position from previous screen.
     *
     * @param bearing — compass bearing to the bird (degrees, 0-360)
     * @param lat — GPS latitude of the hunter's position
     * @param lon — GPS longitude of the hunter's position
     */
    function initialize(bearing as Double, lat as Double, lon as Double) {
        View.initialize();
        _bearing = bearing;
        _capturedLat = lat;
        _capturedLon = lon;
    }

    /**
     * onUpdate() — Draw the distance entry screen.
     *
     * Layout:
     *   - Header with bearing context (e.g., "Bearing: 247° WSW")
     *   - Large distance number with +/- indicators
     *   - Quick-select row: [10] [20] [30] [40]
     *   - NEXT button at bottom
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // --- Header ---
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 25, Graphics.FONT_SMALL,
            "DISTANCE?", Graphics.TEXT_JUSTIFY_CENTER);

        // Show the captured bearing for context
        var cardinal = CoordinateMath.toCardinal(_bearing);
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 50, Graphics.FONT_XTINY,
            "Bearing: " + _bearing.format("%d") + "\u00B0 " + cardinal,
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- Distance counter ---
        // +/- indicators above and below the number
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 75, Graphics.FONT_MEDIUM,
            "+", Graphics.TEXT_JUSTIFY_CENTER);

        // Large distance display
        if (_focusedElement == 0) {
            dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(centerX, 105, Graphics.FONT_NUMBER_THAI_HOT,
            _distanceYards.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        // Unit label — shows "yards" or "meters" based on user's unit setting
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 185, Graphics.FONT_SMALL,
            Constants.getDistanceUnitLabel(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, 210, Graphics.FONT_MEDIUM,
            "-", Graphics.TEXT_JUSTIFY_CENTER);

        // --- Quick-select buttons ---
        var btnWidth = 65;
        var btnHeight = 40;
        var spacing = 10;
        var totalWidth = (_quickDistances.size() * btnWidth) +
                         ((_quickDistances.size() - 1) * spacing);
        var startX = centerX - (totalWidth / 2);
        var quickY = 250;

        for (var i = 0; i < _quickDistances.size(); i++) {
            var btnX = startX + (i * (btnWidth + spacing));
            var btnIdx = i + 1; // Focus indices 1-4

            if (_focusedElement == btnIdx) {
                dc.setColor(Constants.COLOR_PRIMARY, Constants.COLOR_PRIMARY);
                dc.fillRoundedRectangle(btnX, quickY, btnWidth, btnHeight, 6);
                dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(btnX, quickY, btnWidth, btnHeight, 6);
            }

            dc.drawText(btnX + (btnWidth / 2), quickY + 8, Graphics.FONT_XTINY,
                _quickDistances[i].format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- NEXT button ---
        var nextY = 310;
        var nextW = screenW - 140;
        var nextH = 50;
        var nextX = 70;

        if (_focusedElement == 5) {
            dc.setColor(Constants.COLOR_SUCCESS, Constants.COLOR_SUCCESS);
            dc.fillRoundedRectangle(nextX, nextY, nextW, nextH, 8);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(nextX, nextY, nextW, nextH, 8);
        }
        dc.drawText(centerX, nextY + 10, Graphics.FONT_SMALL,
            "NEXT", Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom hint — shows unit-appropriate increment
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        var hintUnit = Constants.isMetric() ? "m" : "yd";
        dc.drawText(centerX, screenH - 30, Graphics.FONT_XTINY,
            "UP/DOWN: +5" + hintUnit, Graphics.TEXT_JUSTIFY_CENTER);
    }

    /** Increase distance by 5 yards. */
    function increment() as Void {
        if (_distanceYards < 200) {
            _distanceYards += 5;
            WatchUi.requestUpdate();
        }
    }

    /** Decrease distance by 5 yards, minimum 5. */
    function decrement() as Void {
        if (_distanceYards > 5) {
            _distanceYards -= 5;
            WatchUi.requestUpdate();
        }
    }
}

/**
 * DistanceEntryDelegate — Input handler for the distance entry screen.
 *
 * UP/DOWN adjusts distance when counter is focused.
 * SELECT activates quick-select buttons or advances to navigation.
 */
class DistanceEntryDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Handle button activation based on focus.
     *
     * Counter focused: jump to NEXT button.
     * Quick-select focused: set distance and jump to NEXT.
     * NEXT focused: calculate target point and launch navigation.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as DistanceEntryView;

        if (view._focusedElement == 0) {
            // Counter focused — jump to NEXT
            view._focusedElement = 5;
            WatchUi.requestUpdate();
        } else if (view._focusedElement >= 1 && view._focusedElement <= 4) {
            // Quick-select — set distance and jump to NEXT
            var quickIdx = view._focusedElement - 1;
            view._distanceYards = view._quickDistances[quickIdx];
            view._focusedElement = 5;
            WatchUi.requestUpdate();
        } else if (view._focusedElement == 5) {
            // NEXT — calculate target point and launch navigation

            // Convert the entered distance to meters for the destinationPoint calculation.
            // If the user entered in meters (metric mode), it's already meters.
            // If in yards (imperial mode), convert yards → meters.
            var distanceMeters = 0.0d;
            if (Constants.isMetric()) {
                distanceMeters = view._distanceYards.toDouble(); // Actually meters in metric mode
            } else {
                distanceMeters = CoordinateMath.yardsToMeters(
                    view._distanceYards.toDouble()
                );
            }

            // Calculate where the bird is based on bearing + distance from hunter
            var targetCoords = CoordinateMath.destinationPoint(
                view._capturedLat, view._capturedLon,
                view._bearing, distanceMeters
            );

            // Create a bird marker and add it to the manager
            var marker = new BirdMarker(
                targetCoords[0] as Double,   // target latitude
                targetCoords[1] as Double,   // target longitude
                view._capturedLat,           // origin latitude
                view._capturedLon,           // origin longitude
                view._bearing,
                view._distanceYards
            );

            BirdMarkerManager.addMarker(marker);

            // Launch the navigation screen to guide the hunter to the bird
            WatchUi.pushView(
                new NavigationView(marker),
                new NavigationDelegate(),
                WatchUi.SLIDE_LEFT
            );
        }
        return true;
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as DistanceEntryView;
        if (view._focusedElement == 0) {
            view.decrement();
        } else if (view._focusedElement < 5) {
            view._focusedElement++;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as DistanceEntryView;
        if (view._focusedElement == 0) {
            view.increment();
        } else {
            view._focusedElement--;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
