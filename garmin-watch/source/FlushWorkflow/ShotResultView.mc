import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

/**
 * ShotResultView — Screen 3 of 5 in the Mark Flush workflow.
 *
 * "What happened?" — Three big buttons:
 *   SHOT  (green)  — Hunter fired and believes they hit at least one bird
 *   MISSED (gray)  — Hunter fired and missed
 *   NO SHOT (muted) — Bird flushed but hunter didn't shoot
 *
 * This is designed for speed. Three big buttons, no scrolling needed.
 * The hunter picks one and moves on.
 *
 * FLOW: SpeciesSelect → Quantity → [ShotResult] → BirdsDown → Confirmation
 */
class ShotResultView extends WatchUi.View {

    // Data carried forward from previous screens
    var _species as Number;
    var _quantity as Number;
    var _coveySize as Number?;
    var _capturedLat as Double;
    var _capturedLon as Double;
    var _capturedTime as Number;

    // Currently highlighted button (0=SHOT, 1=MISSED, 2=NO SHOT)
    var _selectedOption as Number = 0;

    /**
     * Constructor — receives accumulated data from previous workflow screens.
     */
    function initialize(species as Number, quantity as Number, coveySize as Number?,
                         lat as Double, lon as Double, time as Number) {
        View.initialize();
        _species = species;
        _quantity = quantity;
        _coveySize = coveySize;
        _capturedLat = lat;
        _capturedLon = lon;
        _capturedTime = time;
    }

    /**
     * onUpdate() — Draw three large buttons for shot result.
     *
     * Layout optimized for gloved hands:
     *   - Three vertically stacked buttons
     *   - Each button is at least 60px tall (minimum touch target)
     *   - Currently selected button has a thicker border
     *   - Color-coded: green for SHOT, gray for MISSED, muted for NO SHOT
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
            "SHOT RESULT", Graphics.TEXT_JUSTIFY_CENTER);

        // --- SHOT button ---
        var btnWidth = screenW - 100;
        var btnHeight = 70;
        var btnX = 50;
        var shotY = 90;

        // SHOT — green
        if (_selectedOption == 0) {
            dc.setColor(Constants.COLOR_SUCCESS, Constants.COLOR_SUCCESS);
            dc.fillRoundedRectangle(btnX, shotY, btnWidth, btnHeight, 10);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, shotY, btnWidth, btnHeight, 10);
            dc.setColor(Constants.COLOR_SUCCESS, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(centerX, shotY + 20, Graphics.FONT_MEDIUM,
            "SHOT", Graphics.TEXT_JUSTIFY_CENTER);

        // --- MISSED button ---
        var missedY = shotY + btnHeight + 20;
        if (_selectedOption == 1) {
            dc.setColor(Constants.COLOR_MUTED, Constants.COLOR_MUTED);
            dc.fillRoundedRectangle(btnX, missedY, btnWidth, btnHeight, 10);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, missedY, btnWidth, btnHeight, 10);
        }
        dc.drawText(centerX, missedY + 20, Graphics.FONT_MEDIUM,
            "MISSED", Graphics.TEXT_JUSTIFY_CENTER);

        // --- NO SHOT button ---
        var noShotY = missedY + btnHeight + 20;
        if (_selectedOption == 2) {
            dc.setColor(0x6B7280, 0x6B7280); // darker gray
            dc.fillRoundedRectangle(btnX, noShotY, btnWidth, btnHeight, 10);
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x6B7280, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, noShotY, btnWidth, btnHeight, 10);
        }
        dc.drawText(centerX, noShotY + 20, Graphics.FONT_MEDIUM,
            "NO SHOT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /** Move selection up. */
    function selectPrevious() as Void {
        if (_selectedOption > 0) {
            _selectedOption--;
            WatchUi.requestUpdate();
        }
    }

    /** Move selection down. */
    function selectNext() as Void {
        if (_selectedOption < 2) {
            _selectedOption++;
            WatchUi.requestUpdate();
        }
    }

    /**
     * getShotResult() — Returns the shot result enum based on selection.
     */
    function getShotResult() as Number {
        switch (_selectedOption) {
            case 0: return Constants.SHOT_HIT;
            case 1: return Constants.SHOT_MISSED;
            case 2: return Constants.SHOT_NO_SHOT;
            default: return Constants.SHOT_NO_SHOT;
        }
    }
}

/**
 * ShotResultDelegate — Input handler for the shot result screen.
 */
class ShotResultDelegate extends WatchUi.BehaviorDelegate {

    var _debouncer as DebounceHelper;

    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — Confirm shot result, advance to next screen.
     *
     * If SHOT: go to BirdsDown screen to count downed birds.
     * If MISSED or NO SHOT: skip BirdsDown, go straight to Confirmation.
     */
    function onSelect() as Boolean {
        if (!_debouncer.canProcess()) { return true; }

        var view = WatchUi.getCurrentView()[0] as ShotResultView;
        var shotResult = view.getShotResult();

        if (shotResult == Constants.SHOT_HIT) {
            // Hunter hit — need to know how many birds went down
            WatchUi.pushView(
                new BirdsDownView(
                    view._species, view._quantity, view._coveySize,
                    shotResult,
                    view._capturedLat, view._capturedLon, view._capturedTime
                ),
                new BirdsDownDelegate(),
                WatchUi.SLIDE_LEFT
            );
        } else {
            // Missed or no shot — skip to confirmation (0 birds downed).
            // Workflow depth = 4: SpeciesSelect + Quantity + ShotResult + Confirmation.
            WatchUi.pushView(
                new ConfirmationView(
                    view._species, view._quantity, view._coveySize,
                    shotResult, 0,
                    view._capturedLat, view._capturedLon, view._capturedTime,
                    4
                ),
                new ConfirmationDelegate(),
                WatchUi.SLIDE_LEFT
            );
        }
        return true;
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as ShotResultView;
        view.selectNext();
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as ShotResultView;
        view.selectPrevious();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
