import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Position;
import Toybox.Time;
import Toybox.Lang;

/**
 * SpeciesSelectView — Screen 1 of 5 in the Mark Flush workflow.
 *
 * Shows a scrollable list of bird species for the hunter to select.
 * The most recently used species appear first (MRU sorting) so
 * repeat encounters are faster to log.
 *
 * GPS CAPTURE: The GPS position is captured NOW when this view is created,
 * not when the hunter finishes the workflow. The bird is flushing RIGHT NOW —
 * by the time confirmation happens, the hunter may have walked 20 yards.
 *
 * FLOW: SpeciesSelect → Quantity → ShotResult → BirdsDown → Confirmation
 */
class SpeciesSelectView extends WatchUi.View {

    // The GPS coordinates captured at the moment the flush button was pressed.
    // These are passed through the entire workflow and saved with the waypoint.
    var _capturedLat as Double = 0.0d;
    var _capturedLon as Double = 0.0d;
    var _capturedTime as Number = 0;

    // Currently highlighted species index (for scrolling with UP/DOWN buttons)
    var _selectedIndex as Number = 0;

    // Species list in display order (MRU-sorted).
    // This is an array of species enum values (Constants.SPECIES_*).
    var _speciesList as Array<Number>;

    /**
     * Constructor — captures GPS position immediately.
     *
     * This is critical: we grab the position HERE because the bird
     * is flushing RIGHT NOW. The hunter will spend 5-10 seconds going
     * through the workflow screens — we don't want the waypoint to be
     * wherever they end up walking to during that time.
     */
    function initialize() {
        View.initialize();

        // Capture GPS position at this exact moment
        var app = Application.getApp() as UplandHunterApp;
        if (app._lastPosition != null && app._lastPosition.position != null) {
            var coords = app._lastPosition.position.toDegrees();
            _capturedLat = coords[0] as Double;
            _capturedLon = coords[1] as Double;
        }
        _capturedTime = Time.now().value();

        // Build the species list. For now, just use the default order.
        // Phase 1.8 will add MRU sorting from saved preferences.
        _speciesList = [
            Constants.SPECIES_PHEASANT,
            Constants.SPECIES_QUAIL,
            Constants.SPECIES_CHUKAR,
            Constants.SPECIES_GROUSE_RUFFED,
            Constants.SPECIES_GROUSE_SAGE,
            Constants.SPECIES_GROUSE_SHARPTAIL,
            Constants.SPECIES_WOODCOCK,
            Constants.SPECIES_PRAIRIE_CHICKEN,
            Constants.SPECIES_PARTRIDGE,
            Constants.SPECIES_DOVE,
            Constants.SPECIES_OTHER
        ] as Array<Number>;
    }

    /**
     * onUpdate() — Draw the species selection list.
     *
     * Shows a scrollable list with the currently selected species highlighted.
     * On a round watch face, we show ~5 species at a time with the selected
     * one in the center.
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;

        // Clear screen — uses high contrast helper for sunlight readability
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // Header
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 25, Graphics.FONT_SMALL,
            "SELECT SPECIES", Graphics.TEXT_JUSTIFY_CENTER);

        // Draw species list — show up to 5 items centered on selection.
        // On a round screen, items near the top/bottom edges get clipped,
        // so centering the selection ensures it's always fully visible.
        var rowHeight = 45;
        var visibleCount = 6;
        var startItem = _selectedIndex - (visibleCount / 2);

        // Clamp to valid range
        if (startItem < 0) { startItem = 0; }
        if (startItem > _speciesList.size() - visibleCount) {
            startItem = _speciesList.size() - visibleCount;
            if (startItem < 0) { startItem = 0; }
        }

        for (var i = 0; i < visibleCount && (startItem + i) < _speciesList.size(); i++) {
            var idx = startItem + i;
            var y = 70 + (i * rowHeight);
            var species = _speciesList[idx];
            var name = Constants.getSpeciesName(species);

            if (idx == _selectedIndex) {
                // Highlight the selected item with an orange background
                dc.setColor(Constants.COLOR_PRIMARY, Constants.COLOR_PRIMARY);
                dc.fillRectangle(40, y - 5, screenW - 80, rowHeight - 5);
                dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            }

            dc.drawText(centerX, y, Graphics.FONT_SMALL,
                name, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Scroll indicators
        if (startItem > 0) {
            // Show up arrow
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 55, Graphics.FONT_XTINY,
                "^", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (startItem + visibleCount < _speciesList.size()) {
            // Show down arrow
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, screenH - 40, Graphics.FONT_XTINY,
                "v", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint at bottom
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH - 25, Graphics.FONT_XTINY,
            "SELECT to confirm", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * scrollUp() — Move selection up one item.
     */
    function scrollUp() as Void {
        if (_selectedIndex > 0) {
            _selectedIndex--;
            WatchUi.requestUpdate();
        }
    }

    /**
     * scrollDown() — Move selection down one item.
     */
    function scrollDown() as Void {
        if (_selectedIndex < _speciesList.size() - 1) {
            _selectedIndex++;
            WatchUi.requestUpdate();
        }
    }

    /**
     * getSelectedSpecies() — Returns the currently highlighted species enum value.
     */
    function getSelectedSpecies() as Number {
        return _speciesList[_selectedIndex];
    }
}

/**
 * SpeciesSelectDelegate — Input handler for the species selection screen.
 *
 * UP/DOWN scrolls the list, SELECT confirms the species and advances
 * to the Quantity screen, BACK cancels and returns to the main view.
 */
class SpeciesSelectDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Confirm species selection, advance to Quantity screen.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        // Get the current view to access its data
        var view = WatchUi.getCurrentView()[0] as SpeciesSelectView;
        var species = view.getSelectedSpecies();

        // Pass the captured GPS data and species to the next screen
        WatchUi.pushView(
            new QuantityView(species, view._capturedLat, view._capturedLon, view._capturedTime),
            new QuantityDelegate(),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }

    /**
     * onNextPage() / onPreviousPage() — Scroll the species list.
     * These map to UP/DOWN buttons on Garmin watches.
     */
    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as SpeciesSelectView;
        view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as SpeciesSelectView;
        view.scrollUp();
        return true;
    }

    /**
     * onBack() — Cancel the flush workflow, return to main screen.
     */
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
