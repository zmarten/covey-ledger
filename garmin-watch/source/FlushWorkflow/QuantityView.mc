import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

/**
 * QuantityView — Screen 2 of 5 in the Mark Flush workflow.
 *
 * "How many birds flushed?"
 *
 * Shows a large number with +/- buttons. For quail and partridge,
 * also shows a covey size selector since these birds flush in coveys
 * and the total count matters for harvest tracking.
 *
 * FLOW: SpeciesSelect → [Quantity] → ShotResult → BirdsDown → Confirmation
 */
class QuantityView extends WatchUi.View {

    // Data carried forward from previous screen
    var _species as Number;
    var _capturedLat as Double;
    var _capturedLon as Double;
    var _capturedTime as Number;

    // Current quantity value
    var _quantity as Number = 1;

    // Covey size — only used for quail/partridge
    // null means covey size was not specified
    var _coveySize as Number? = null;

    // Whether this species supports covey size (quail, partridge)
    var _isCoveySpecies as Boolean = false;

    // Quick-select covey sizes for quail/partridge
    // These are common covey sizes observed in the field
    static var COVEY_SIZES = [8, 12, 16, 20, 25];

    /**
     * Constructor — receives data from the species selection screen.
     *
     * @param species — the selected species enum value
     * @param lat — captured GPS latitude
     * @param lon — captured GPS longitude
     * @param time — capture timestamp
     */
    function initialize(species as Number, lat as Double, lon as Double, time as Number) {
        View.initialize();
        _species = species;
        _capturedLat = lat;
        _capturedLon = lon;
        _capturedTime = time;

        // Quail and partridge are covey birds — they flush in groups
        // and hunters often want to record the total covey size
        _isCoveySpecies = (species == Constants.SPECIES_QUAIL ||
                           species == Constants.SPECIES_PARTRIDGE);
    }

    /**
     * onUpdate() — Draw the quantity selection screen.
     *
     * Layout:
     *   - Header: "How Many?" + species name
     *   - Center: Large quantity number
     *   - Buttons: [-] and [+] indicators for UP/DOWN buttons
     *   - Bottom: Covey size options (for quail/partridge only)
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // Header — species name
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 30, Graphics.FONT_SMALL,
            "HOW MANY?", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 55, Graphics.FONT_XTINY,
            Constants.getSpeciesName(_species), Graphics.TEXT_JUSTIFY_CENTER);

        // Large quantity display in the center
        dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH / 2 - 40, Graphics.FONT_NUMBER_THAI_HOT,
            _quantity.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        // +/- indicators
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH / 2 - 85, Graphics.FONT_MEDIUM,
            "+", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, screenH / 2 + 30, Graphics.FONT_MEDIUM,
            "-", Graphics.TEXT_JUSTIFY_CENTER);

        // Covey size selector for quail/partridge
        if (_isCoveySpecies) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, screenH - 80, Graphics.FONT_XTINY,
                "Covey: " + (_coveySize != null ? _coveySize.format("%d") : "N/A"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Bottom hint
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 35, Graphics.FONT_XTINY,
            "UP/DOWN: +/-  SELECT: Next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /** Increase quantity by 1. */
    function increment() as Void {
        // Cap at 99 — no single flush has more than 99 birds
        if (_quantity < 99) {
            _quantity++;
            WatchUi.requestUpdate();
        }
    }

    /** Decrease quantity by 1, minimum 1. */
    function decrement() as Void {
        if (_quantity > 1) {
            _quantity--;
            WatchUi.requestUpdate();
        }
    }
}

/**
 * QuantityDelegate — Input handler for the quantity screen.
 *
 * UP/DOWN adjusts the count, SELECT advances to Shot Result.
 */
class QuantityDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Confirm quantity, advance to Shot Result screen.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as QuantityView;

        WatchUi.pushView(
            new ShotResultView(
                view._species, view._quantity, view._coveySize,
                view._capturedLat, view._capturedLon, view._capturedTime
            ),
            new ShotResultDelegate(),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }

    /**
     * onNextPage() — DOWN button: decrease quantity.
     * Using DOWN for decrease feels natural (number goes down).
     */
    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as QuantityView;
        view.decrement();
        return true;
    }

    /**
     * onPreviousPage() — UP button: increase quantity.
     */
    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as QuantityView;
        view.increment();
        return true;
    }

    /**
     * onBack() — Go back to species selection.
     */
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
