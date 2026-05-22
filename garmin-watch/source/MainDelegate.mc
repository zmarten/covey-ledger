import Toybox.WatchUi;
import Toybox.System;
import Toybox.Application;
import Toybox.Lang;

/**
 * MainDelegate — Input handler for the main hunt screen.
 *
 * Handles all button presses and touch events on the MainView.
 * Connect IQ separates "what's displayed" (View) from "what happens
 * when you press a button" (InputDelegate/BehaviorDelegate).
 *
 * BUTTON MAPPING (Fenix 8 Solar):
 *   - SELECT (middle-right button): Start hunt OR Mark Flush (context-dependent)
 *   - MENU (long-press middle-right): Open main menu (end hunt, stats)
 *   - UP/DOWN: Scroll dog list (Phase 4)
 *   - BACK (bottom-left): Exit app
 *
 * WHY BehaviorDelegate instead of InputDelegate:
 * BehaviorDelegate maps to abstract behaviors (onSelect, onBack, onMenu)
 * rather than raw button IDs. This means our code works on any Garmin
 * device regardless of button layout — the system translates hardware
 * buttons to behaviors for us.
 */
class MainDelegate extends WatchUi.BehaviorDelegate {

    // Debounce helper prevents glove-induced double-taps
    var _debouncer as DebounceHelper;

    /**
     * Constructor — set up the input handler with debouncing.
     */
    function initialize() {
        BehaviorDelegate.initialize();
        _debouncer = new DebounceHelper(null);
    }

    /**
     * onSelect() — SELECT button pressed.
     *
     * Context-dependent behavior:
     *   - Hunt NOT active: Start a new hunt
     *   - Hunt active: Launch the Mark Flush workflow (Phase 1.4)
     *
     * SELECT is the most-used button during a hunt. A quick press
     * marks a flush — this needs to be fast and reliable.
     *
     * @return true if we handled the event, false to pass it along
     */
    function onSelect() as Boolean {
        // Debounce check — ignore glove bounces
        if (!_debouncer.canProcess()) {
            return true;
        }

        var app = Application.getApp() as UplandHunterApp;

        if (app.isHuntActive()) {
            // Hunt is active — SELECT triggers Mark Flush workflow.
            // Push the species selection screen (first step of the 5-screen workflow).
            // The GPS position is captured HERE, at the moment the hunter presses
            // the button — NOT later when they confirm. The bird flushes NOW.
            WatchUi.pushView(
                new SpeciesSelectView(),
                new SpeciesSelectDelegate(),
                WatchUi.SLIDE_UP
            );
        } else {
            // No active hunt — start one
            app.startHuntActivity();
            WatchUi.requestUpdate();
        }

        return true;
    }

    /**
     * onMenu() — MENU button pressed (long-press SELECT on most devices).
     *
     * Opens the main menu. We build the menu dynamically based on
     * hunt state — showing "Start Hunt" or "End Hunt" as appropriate.
     *
     * @return true if we handled the event
     */
    function onMenu() as Boolean {
        var app = Application.getApp() as UplandHunterApp;

        // Create a Menu2 (the modern Garmin menu style with icons)
        var menu = new WatchUi.Menu2({:title => "Upland Hunter"});

        if (app.isHuntActive()) {
            // Hunt is running — show stats, map, and end hunt options
            menu.addItem(new WatchUi.MenuItem("Session Stats", "View hunt stats", "MenuStats", null));
            menu.addItem(new WatchUi.MenuItem("Map View", "View hunt map", "MenuMap", null));
            menu.addItem(new WatchUi.MenuItem("End Hunt", "Stop and save", "MenuEndHunt", null));
        } else {
            // No hunt — show start option
            menu.addItem(new WatchUi.MenuItem("Start Hunt", "Begin recording", "MenuStartHunt", null));
        }

        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    /**
     * onBack() — BACK button pressed.
     *
     * On the main view, BACK exits the app.
     * If a hunt is active, the activity is saved in onStop().
     *
     * @return false — let the system handle app exit
     */
    function onBack() as Boolean {
        return false;
    }
}

/**
 * MainMenuDelegate — Handles selections from the main menu.
 *
 * Routes menu item taps to the appropriate action.
 */
class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    /**
     * Constructor.
     */
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    /**
     * onSelect() — A menu item was tapped.
     *
     * We identify which item by its string ID and take action.
     *
     * @param item — the MenuItem that was selected
     */
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var app = Application.getApp() as UplandHunterApp;

        if (id.equals("MenuStartHunt")) {
            // Start recording a new hunt activity
            app.startHuntActivity();
            WatchUi.popView(WatchUi.SLIDE_DOWN);

        } else if (id.equals("MenuEndHunt")) {
            // Pop the menu, then show the post-hunt summary.
            // The summary view calls stopHuntActivity() when the user dismisses it,
            // so the FIT file captures the final stats before saving.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.pushView(
                new PostHuntSummaryView(),
                new PostHuntSummaryDelegate(),
                WatchUi.SLIDE_UP
            );

        } else if (id.equals("MenuStats")) {
            // Replace the menu with the stats view
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.pushView(
                new SessionStatsView(),
                new SessionStatsDelegate(),
                WatchUi.SLIDE_UP
            );

        } else if (id.equals("MenuMap")) {
            // Replace the menu with the map view (Phase 3)
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.pushView(
                new HuntMapView(),
                new HuntMapDelegate(),
                WatchUi.SLIDE_UP
            );
        }
    }

    /**
     * onBack() — BACK pressed in the menu.
     * Pop the menu to return to the main screen.
     */
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
