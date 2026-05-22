import Toybox.System;
import Toybox.Lang;

/**
 * DebounceHelper — Prevents accidental double-taps on buttons.
 *
 * WHY THIS EXISTS: Hunters wear thick gloves. When they press a button
 * on the watch, the glove often causes multiple rapid presses (bouncing).
 * Without debouncing, a single intended tap could register as 2-3 taps,
 * causing the flush workflow to skip screens or record double entries.
 *
 * HOW IT WORKS: Each time a button is pressed, we record the timestamp.
 * If the next press comes within DEBOUNCE_MS (500ms), we ignore it.
 * 500ms is fast enough that the user won't notice a delay, but slow
 * enough to catch glove-induced bounces.
 *
 * USAGE EXAMPLE:
 *   var debouncer = new DebounceHelper();
 *   function onSelect() {
 *       if (!debouncer.canProcess()) { return true; }  // bounce — ignore
 *       // ... handle the real button press ...
 *   }
 */
class DebounceHelper {

    // Timestamp of the last accepted button press (in milliseconds).
    // System.getTimer() returns ms since app start.
    var _lastEventTime as Number = 0;

    // How long to wait between accepted presses (ms).
    // Reads from Constants.DEBOUNCE_MS (500ms by default).
    var _debounceMs as Number;

    /**
     * Constructor — create a new debounce helper.
     *
     * @param debounceMs — optional custom debounce duration in milliseconds.
     *                     Defaults to Constants.DEBOUNCE_MS (500ms).
     */
    function initialize(debounceMs as Number?) {
        if (debounceMs != null) {
            _debounceMs = debounceMs;
        } else {
            _debounceMs = Constants.DEBOUNCE_MS;
        }
    }

    /**
     * canProcess() — Should we process this button press?
     *
     * Returns true if enough time has passed since the last accepted press.
     * Also updates the last event time when returning true, so the next
     * call starts the debounce window from this moment.
     *
     * @return true if this press should be processed, false if it's a bounce
     */
    function canProcess() as Boolean {
        var now = System.getTimer();

        // Check if we're still within the debounce window
        if (now - _lastEventTime < _debounceMs) {
            // Too soon — this is a bounce, ignore it
            return false;
        }

        // Enough time has passed — accept this press and reset the window
        _lastEventTime = now;
        return true;
    }

    /**
     * reset() — Reset the debounce timer.
     *
     * Call this when you want the next button press to always be accepted,
     * regardless of timing. Useful when switching between screens — you
     * don't want the debounce from the previous screen to block the first
     * press on the new screen.
     */
    function reset() as Void {
        _lastEventTime = 0;
    }
}
