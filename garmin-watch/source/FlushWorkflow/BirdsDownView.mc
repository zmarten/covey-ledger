import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Lang;

/**
 * BirdsDownView — Screen 4 of 5 in the Mark Flush workflow.
 *
 * "How many birds went down?"
 *
 * Only shown when the hunter selected SHOT on the previous screen.
 * Shows a counter with +/- buttons, capped at the number flushed.
 * Also has a "MARK BIRD" button that triggers the Downed Bird Locator
 * (Phase 2) to help the hunter find and retrieve the bird.
 *
 * FLOW: SpeciesSelect → Quantity → ShotResult → [BirdsDown] → Confirmation
 */
class BirdsDownView extends WatchUi.View {

    // Accumulated data from previous screens
    var _species as Number;
    var _quantityFlushed as Number;
    var _coveySize as Number?;
    var _shotResult as Number;
    var _capturedLat as Double;
    var _capturedLon as Double;
    var _capturedTime as Number;

    // Number of birds downed — starts at 1 (they said they hit, so at least 1)
    var _birdsDown as Number = 1;

    // Currently focused UI element:
    // 0 = birds down counter, 1 = MARK BIRD button, 2 = SAVE button
    var _focusedElement as Number = 0;

    /**
     * Constructor — receives workflow data and initializes birds down count.
     */
    function initialize(species as Number, quantityFlushed as Number, coveySize as Number?,
                         shotResult as Number,
                         lat as Double, lon as Double, time as Number) {
        View.initialize();
        _species = species;
        _quantityFlushed = quantityFlushed;
        _coveySize = coveySize;
        _shotResult = shotResult;
        _capturedLat = lat;
        _capturedLon = lon;
        _capturedTime = time;
        _birdsDown = 1;  // Default to 1 since they said they hit
    }

    /**
     * onUpdate() — Draw the birds down counter and action buttons.
     *
     * Layout:
     *   - Header: "Birds Down"
     *   - Center: Large number with +/- indicators
     *   - Bottom: MARK BIRD button (orange) and SAVE button (green)
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // Header
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 30, Graphics.FONT_SMALL,
            "BIRDS DOWN", Graphics.TEXT_JUSTIFY_CENTER);

        // Species and flush count context
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 55, Graphics.FONT_XTINY,
            Constants.getSpeciesName(_species) + " - " + _quantityFlushed + " flushed",
            Graphics.TEXT_JUSTIFY_CENTER);

        // +/- indicators
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 80, Graphics.FONT_MEDIUM,
            "+", Graphics.TEXT_JUSTIFY_CENTER);

        // Large birds down count
        if (_focusedElement == 0) {
            dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(centerX, 110, Graphics.FONT_NUMBER_THAI_HOT,
            _birdsDown.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 195, Graphics.FONT_MEDIUM,
            "-", Graphics.TEXT_JUSTIFY_CENTER);

        // --- MARK BIRD button ---
        // This launches the Downed Bird Locator (Phase 2)
        var btnWidth = screenW - 120;
        var markY = 240;
        var btnHeight = 55;

        if (_focusedElement == 1) {
            dc.setColor(Constants.COLOR_PRIMARY, Constants.COLOR_PRIMARY);
            dc.fillRoundedRectangle(60, markY, btnWidth, btnHeight, 8);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(60, markY, btnWidth, btnHeight, 8);
        }
        dc.drawText(centerX, markY + 12, Graphics.FONT_SMALL,
            "MARK BIRD", Graphics.TEXT_JUSTIFY_CENTER);

        // --- SAVE button ---
        var saveY = markY + btnHeight + 15;
        if (_focusedElement == 2) {
            dc.setColor(Constants.COLOR_SUCCESS, Constants.COLOR_SUCCESS);
            dc.fillRoundedRectangle(60, saveY, btnWidth, btnHeight, 8);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(60, saveY, btnWidth, btnHeight, 8);
        }
        dc.drawText(centerX, saveY + 12, Graphics.FONT_SMALL,
            "SAVE", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /** Increase birds downed, capped at quantity flushed. */
    function increment() as Void {
        if (_birdsDown < _quantityFlushed) {
            _birdsDown++;
            WatchUi.requestUpdate();
        }
    }

    /** Decrease birds downed, minimum 0. */
    function decrement() as Void {
        if (_birdsDown > 0) {
            _birdsDown--;
            WatchUi.requestUpdate();
        }
    }

    /** Move focus to next UI element. */
    function focusNext() as Void {
        if (_focusedElement < 2) {
            _focusedElement++;
            WatchUi.requestUpdate();
        }
    }

    /** Move focus to previous UI element. */
    function focusPrevious() as Void {
        if (_focusedElement > 0) {
            _focusedElement--;
            WatchUi.requestUpdate();
        }
    }
}

/**
 * BirdsDownDelegate — Input handler for the birds down screen.
 *
 * UP/DOWN adjusts count when counter is focused, or moves focus.
 * SELECT activates the focused button.
 */
class BirdsDownDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Handle button activation based on focused element.
     *
     * When counter is focused: move focus to SAVE button.
     * When MARK BIRD is focused: launch Downed Bird Locator (Phase 2).
     * When SAVE is focused: save the waypoint and go to confirmation.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as BirdsDownView;

        if (view._focusedElement == 0) {
            // Counter focused — move to SAVE for quick workflow
            view._focusedElement = 2;
            WatchUi.requestUpdate();
        } else if (view._focusedElement == 1) {
            // MARK BIRD focused — launch the Downed Bird Locator.
            // Pass the hunter's current GPS position so the bearing capture
            // knows where the hunter is standing right now.
            var app = Application.getApp() as UplandHunterApp;
            var lat = 0.0d;
            var lon = 0.0d;
            if (app._lastPosition != null && app._lastPosition.position != null) {
                var coords = app._lastPosition.position.toDegrees();
                lat = coords[0] as Double;
                lon = coords[1] as Double;
            }
            WatchUi.pushView(
                new BearingCaptureView(lat, lon),
                new BearingCaptureDelegate(),
                WatchUi.SLIDE_UP
            );
        } else if (view._focusedElement == 2) {
            // SAVE focused — go to confirmation screen.
            // Workflow depth = 5: SpeciesSelect + Quantity + ShotResult + BirdsDown + Confirmation.
            WatchUi.pushView(
                new ConfirmationView(
                    view._species, view._quantityFlushed, view._coveySize,
                    view._shotResult, view._birdsDown,
                    view._capturedLat, view._capturedLon, view._capturedTime,
                    5
                ),
                new ConfirmationDelegate(),
                WatchUi.SLIDE_LEFT
            );
        }
        return true;
    }

    /**
     * onNextPage() — DOWN button behavior depends on focus.
     * Counter: decrease count. Buttons: move focus down.
     */
    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as BirdsDownView;
        if (view._focusedElement == 0) {
            view.decrement();
        } else {
            view.focusNext();
        }
        return true;
    }

    /**
     * onPreviousPage() — UP button: increase count or move focus up.
     */
    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as BirdsDownView;
        if (view._focusedElement == 0) {
            view.increment();
        } else {
            view.focusPrevious();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
