import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Timer;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Attention;

/**
 * MainView — The primary hunt screen. This is what the hunter sees 90% of the time.
 *
 * LAYOUT (454x454 round screen, fenix8solar51mm):
 * ┌──────────────────────────────────┐
 * │          UPLAND HUNTER           │  <- Orange header text
 * │           GPS Ready              │  <- Green/gray GPS status
 * │                                  │
 * │          00:45:23                │  <- Hunt timer (large)
 * │         Hunt Active              │  <- Status label
 * │                                  │
 * │  ┌──────────────────────────┐    │
 * │  │  Rex         45 yd  →   │    │  <- Dog entry (placeholder)
 * │  │  Belle       120 yd ↗   │    │  <- Color-coded distance
 * │  │  Duke        ON POINT!  │    │  <- Alert state
 * │  └──────────────────────────┘    │
 * │                                  │
 * │     SELECT: Flush | MENU: More   │  <- Bottom hints
 * └──────────────────────────────────┘
 *
 * The timer updates every second via a Toybox.Timer to keep the
 * elapsed time display current without burning CPU.
 */
class MainView extends WatchUi.View {

    // Timer for refreshing the screen every second (hunt timer display).
    // We only run this timer when a hunt is active to save battery.
    var _refreshTimer as Timer.Timer?;

    // Tracks previous dog statuses to detect ON POINT/TREED transitions.
    // Key = dog ID, value = previous status. When status changes to
    // ON_POINT or TREED, we trigger haptic vibration.
    var _prevDogStatuses as Dictionary = {} as Dictionary;

    /**
     * Constructor — initialize the view.
     */
    function initialize() {
        View.initialize();
        _refreshTimer = null;
    }

    /**
     * onLayout() — set up layout resources.
     * We draw everything custom, so nothing to load here.
     */
    function onLayout(dc as Graphics.Dc) as Void {
        // Custom drawing in onUpdate() — no XML layout
    }

    /**
     * onShow() — called when this view becomes visible.
     *
     * Starts the 1-second refresh timer if a hunt is active,
     * so the elapsed time display updates smoothly.
     */
    function onShow() as Void {
        // Start the refresh timer — ticks every 1 second to update the hunt clock
        startRefreshTimer();
    }

    /**
     * onUpdate() — Main rendering function. Draws the entire screen.
     *
     * This is called every time the screen needs redrawing:
     * timer tick, GPS update, returning from another view, etc.
     *
     * PERFORMANCE NOTE: Avoid allocating objects inside this function.
     * Each allocation uses precious memory and the garbage collector
     * has to clean it up. Use class-level variables instead.
     */
    function onUpdate(dc as Graphics.Dc) as Void {
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var centerX = screenW / 2;
        var app = Application.getApp() as UplandHunterApp;

        // --- Clear screen with dark background ---
        // Uses high contrast helper: pure black background in bright sunlight mode
        dc.setColor(Constants.getTextColor(), Constants.getBgColor());
        dc.clear();

        // --- HEADER: App name in orange ---
        dc.setColor(Constants.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 30, Graphics.FONT_SMALL,
            "UPLAND HUNTER", Graphics.TEXT_JUSTIFY_CENTER);

        // --- GPS STATUS: Green when locked, gray when searching ---
        var gpsText = "Waiting for GPS...";
        var gpsColor = Constants.COLOR_MUTED;
        if (app._hasGpsFix) {
            gpsText = "GPS Ready";
            gpsColor = Constants.COLOR_SUCCESS;
        }
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 55, Graphics.FONT_XTINY,
            gpsText, Graphics.TEXT_JUSTIFY_CENTER);

        // --- MAIN CONTENT AREA ---
        if (app.isHuntActive()) {
            // Hunt is active — show timer and dog list
            drawHuntTimer(dc, centerX, screenH, app);
            drawDogList(dc, centerX, screenW, screenH);
        } else {
            // No active hunt — show start prompt
            drawStartPrompt(dc, centerX, screenH);
        }

        // --- BOTTOM ACTION HINTS ---
        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        if (app.isHuntActive()) {
            dc.drawText(centerX, screenH - 45, Graphics.FONT_XTINY,
                "SELECT: Flush", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(centerX, screenH - 45, Graphics.FONT_XTINY,
                "SELECT: Start Hunt", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    /**
     * drawHuntTimer() — Renders the elapsed hunt time in HH:MM:SS format.
     *
     * Uses the largest available font so it's readable at a glance
     * while hiking through brush.
     */
    function drawHuntTimer(dc as Graphics.Dc, centerX as Number,
                            screenH as Number, app as UplandHunterApp) as Void {
        var duration = app.getHuntDuration();
        var hours = duration / 3600;
        var minutes = (duration % 3600) / 60;
        var seconds = duration % 60;

        // Format as HH:MM:SS with leading zeros
        var timeStr = hours.format("%02d") + ":" +
                      minutes.format("%02d") + ":" +
                      seconds.format("%02d");

        dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 80, Graphics.FONT_LARGE,
            timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 115, Graphics.FONT_XTINY,
            "Hunt Active", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * drawDogList() — Renders the dog tracking list from live dog sensor data.
     *
     * Reads live dog data from DogTrackerSensor and displays each dog's
     * name, distance (color-coded), and status.
     *
     * Distance color coding:
     *   Green (< 30yd) = close, good
     *   Yellow (30-100yd) = medium, moving away
     *   Red (> 100yd) = far, watch carefully
     *
     * ON POINT gets a special red background to grab attention immediately.
     * TREED gets a similar alert treatment.
     *
     * Also checks for status transitions to trigger haptic alerts.
     */
    function drawDogList(dc as Graphics.Dc, centerX as Number,
                          screenW as Number, screenH as Number) as Void {
        // Get dog data from the real ANT+ sensor (Alpha/Astro handheld)
        var app = Application.getApp() as UplandHunterApp;
        var dogs = app._dogTracker.getDogs();
        var connState = app._dogTracker.getConnectionState();

        // Show connection state if not connected
        if (connState == Constants.ANT_STATE_SEARCHING) {
            dc.setColor(Constants.COLOR_WARNING, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 150, Graphics.FONT_SMALL,
                "Searching for dogs...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        } else if (connState != Constants.ANT_STATE_CONNECTED || dogs.size() == 0) {
            dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 150, Graphics.FONT_SMALL,
                "No dogs connected", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Starting Y position for the dog list
        var startY = 145;
        var rowHeight = 40;
        var leftPad = 50;

        for (var i = 0; i < dogs.size() && i < 4; i++) {
            var dog = dogs[i] as DogData;
            var y = startY + (i * rowHeight);

            // Check for ON POINT or TREED status transition → trigger alert
            checkDogAlert(dog);

            // If dog is ON POINT or TREED, draw a red alert background
            if (dog.status == Constants.DOG_STATUS_ON_POINT ||
                dog.status == Constants.DOG_STATUS_TREED) {
                dc.setColor(Constants.COLOR_ALERT, Constants.COLOR_ALERT);
                dc.fillRectangle(leftPad - 10, y - 2, screenW - (leftPad * 2) + 20, rowHeight - 4);
            }

            // Dog name — left aligned
            dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(leftPad, y, Graphics.FONT_SMALL,
                dog.name, Graphics.TEXT_JUSTIFY_LEFT);

            // Distance or status text — right aligned
            if (dog.status == Constants.DOG_STATUS_ON_POINT) {
                dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW - leftPad, y, Graphics.FONT_SMALL,
                    "POINT!", Graphics.TEXT_JUSTIFY_RIGHT);
            } else if (dog.status == Constants.DOG_STATUS_TREED) {
                dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW - leftPad, y, Graphics.FONT_SMALL,
                    "TREED!", Graphics.TEXT_JUSTIFY_RIGHT);
            } else if (dog.status == Constants.DOG_STATUS_COMM_LOST) {
                dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW - leftPad, y, Graphics.FONT_SMALL,
                    "Lost", Graphics.TEXT_JUSTIFY_RIGHT);
            } else if (dog.status == Constants.DOG_STATUS_GPS_LOST) {
                dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW - leftPad, y, Graphics.FONT_SMALL,
                    "No GPS", Graphics.TEXT_JUSTIFY_RIGHT);
            } else {
                // Show distance with color coding.
                // Uses Constants.formatDogDistance() so it respects the
                // user's unit setting (yards or meters).
                var distColor = getDistanceColor(dog.distanceYards);
                dc.setColor(distColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW - leftPad, y, Graphics.FONT_SMALL,
                    Constants.formatDogDistance(dog.distanceYards),
                    Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
    }

    /**
     * checkDogAlert() — Detect ON POINT or TREED transitions and fire haptic alert.
     *
     * Compares the dog's current status against its previous known status.
     * If the dog just went ON POINT or TREED (wasn't before), trigger
     * a strong haptic vibration to alert the hunter immediately.
     *
     * This is critical in the field — a dog going on point means birds
     * are close, and the hunter needs to be ready NOW.
     *
     * @param dog — the DogData to check for status transition
     */
    function checkDogAlert(dog as DogData) as Void {
        var prevStatus = _prevDogStatuses.get(dog.id);

        // Check if this is a NEW alert (status just changed to ON_POINT or TREED)
        if (dog.status == Constants.DOG_STATUS_ON_POINT ||
            dog.status == Constants.DOG_STATUS_TREED) {

            if (prevStatus == null || prevStatus != dog.status) {
                // New alert! Trigger haptic vibration.
                triggerPointAlert();
            }
        }

        // Store current status for next comparison
        _prevDogStatuses.put(dog.id, dog.status);
    }

    /**
     * triggerPointAlert() — Fire haptic vibration for ON POINT / TREED alert.
     *
     * Uses a strong, attention-grabbing vibration pattern.
     * Three short buzzes in quick succession — unmissable even while
     * walking through brush with gloves on.
     */
    function triggerPointAlert() as Void {
        // Check if haptic is enabled in settings
        var hapticEnabled = Application.Properties.getValue("hapticEnabled");
        if (hapticEnabled != null && !hapticEnabled) {
            return;
        }

        // Three short, strong vibration pulses
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(100, 200),  // Strong buzz, 200ms
                new Attention.VibeProfile(0, 100),    // Pause, 100ms
                new Attention.VibeProfile(100, 200),  // Strong buzz, 200ms
                new Attention.VibeProfile(0, 100),    // Pause, 100ms
                new Attention.VibeProfile(100, 200)   // Strong buzz, 200ms
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(vibeData);
        }
    }

    /**
     * drawStartPrompt() — Shows "Press START to begin" when no hunt is active.
     */
    function drawStartPrompt(dc as Graphics.Dc, centerX as Number,
                              screenH as Number) as Void {
        dc.setColor(Constants.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH / 2 - 30, Graphics.FONT_MEDIUM,
            "Press SELECT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Constants.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, screenH / 2 + 10, Graphics.FONT_SMALL,
            "to start hunting", Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
     * getDistanceColor() — Returns the appropriate color for a dog's distance.
     *
     * Green = close (safe, dog is nearby)
     * Yellow = medium (pay attention, dog is ranging)
     * Red = far (dog is distant, might be on scent)
     *
     * @param distanceYards — the dog's distance in yards
     * @return color constant for rendering
     */
    function getDistanceColor(distanceYards as Number) as Number {
        if (distanceYards < Constants.DISTANCE_CLOSE_THRESHOLD) {
            return Constants.COLOR_SUCCESS;  // Green — close
        } else if (distanceYards < Constants.DISTANCE_FAR_THRESHOLD) {
            return Constants.COLOR_WARNING;  // Yellow — medium
        }
        return Constants.COLOR_ALERT;  // Red — far
    }

    /**
     * startRefreshTimer() — Start the 1-second screen refresh timer.
     *
     * This causes onUpdate() to be called every second, keeping
     * the hunt timer display accurate.
     */
    function startRefreshTimer() as Void {
        if (_refreshTimer == null) {
            _refreshTimer = new Timer.Timer();
        }
        // Timer fires every 1000ms (1 second), repeating
        _refreshTimer.start(method(:onTimerTick), 1000, true);
    }

    /**
     * onTimerTick() — Called every second by the refresh timer.
     * Simply requests a screen update to refresh the hunt timer.
     */
    function onTimerTick() as Void {
        WatchUi.requestUpdate();
    }

    /**
     * onHide() — called when this view is no longer visible.
     * Stop the timer to save battery while other views are showing.
     */
    function onHide() as Void {
        if (_refreshTimer != null) {
            _refreshTimer.stop();
        }
    }
}
