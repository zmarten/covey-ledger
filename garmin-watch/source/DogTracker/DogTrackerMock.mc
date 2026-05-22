import Toybox.Lang;
import Toybox.Timer;
import Toybox.Time;
import Toybox.Math;
import Toybox.System;

/**
 * DogTrackerMock — Generates realistic mock dog data for development.
 *
 * Since the ANT+ dog tracker protocol requires real Alpha/Astro hardware
 * to test, this module provides fake data so we can build and test the
 * entire UI without hardware.
 *
 * SIMULATES:
 *   - 3 dogs (Rex, Belle, Duke) with different behavior patterns
 *   - Distances that change gradually (dogs wandering in the field)
 *   - Direction changes (dogs moving around the hunter)
 *   - Periodic ON POINT alert (Duke goes on point every ~30 seconds)
 *   - Battery levels that slowly decrease
 *   - Connection state (shows as "connected" after brief "searching" delay)
 *
 * The mock data is designed to exercise all UI features:
 *   - Color-coded distances (green, yellow, red)
 *   - ON POINT red background alert
 *   - Status text rendering (moving, stationary, on point)
 *   - Map view dog markers (using calculated positions)
 *
 * USAGE:
 *   DogTrackerMock.start();  // Begin generating mock data
 *   var dogs = DogTrackerMock.getDogs();  // Get current dog states
 *   DogTrackerMock.stop();   // Stop generating data
 */
module DogTrackerMock {

    // Array of mock DogData objects.
    // Module-level var acts like a singleton — one shared data set.
    var _dogs as Array<DogData> = [] as Array<DogData>;

    // Helper object that owns the timer callback.
    // Modules can't use method() (no 'self'), so we delegate to a class instance.
    var _timerHelper as DogMockTimerHelper?;

    // Counter for timing events (ON POINT trigger, etc.)
    var _tickCount as Number = 0;

    // Whether the mock tracker is active
    var _isActive as Boolean = false;

    // Connection state (simulates searching → connected)
    var _connectionState as Number = Constants.ANT_STATE_IDLE;

    /**
     * start() — Begin generating mock dog data.
     *
     * Creates 3 dogs with different initial positions and starts
     * a 1-second timer that gradually changes their data.
     * Simulates a brief "searching" phase before showing "connected."
     */
    function start() as Void {
        if (_isActive) { return; }
        _isActive = true;
        _tickCount = 0;

        // Simulate searching for the handheld
        _connectionState = Constants.ANT_STATE_SEARCHING;

        // Create 3 mock dogs with different starting positions
        _dogs = [] as Array<DogData>;

        // Rex — close-range, active dog
        var rex = new DogData("Rex", 1);
        rex.distanceYards = 45;
        rex.direction = 90.0d;
        rex.status = Constants.DOG_STATUS_MOVING;
        rex.batteryPercent = 85;
        rex.signalQuality = 90;
        rex.lastUpdateTime = Time.now().value();
        _dogs.add(rex);

        // Belle — medium-range, tends to be stationary
        var belle = new DogData("Belle", 2);
        belle.distanceYards = 120;
        belle.direction = 45.0d;
        belle.status = Constants.DOG_STATUS_STATIONARY;
        belle.batteryPercent = 72;
        belle.signalQuality = 75;
        belle.lastUpdateTime = Time.now().value();
        _dogs.add(belle);

        // Duke — close-range pointer, goes ON POINT periodically
        var duke = new DogData("Duke", 3);
        duke.distanceYards = 25;
        duke.direction = 180.0d;
        duke.status = Constants.DOG_STATUS_MOVING;
        duke.batteryPercent = 93;
        duke.signalQuality = 95;
        duke.lastUpdateTime = Time.now().value();
        _dogs.add(duke);

        // Start the mock update timer — fires every 1 second.
        // Uses a helper class because modules can't use method() directly.
        _timerHelper = new DogMockTimerHelper();
        _timerHelper.start();

        System.println("DogTrackerMock started with 3 mock dogs");
    }

    /**
     * stop() — Stop generating mock data.
     */
    function stop() as Void {
        _isActive = false;
        _connectionState = Constants.ANT_STATE_IDLE;
        if (_timerHelper != null) {
            _timerHelper.stop();
            _timerHelper = null;
        }
        System.println("DogTrackerMock stopped");
    }

    /**
     * getDogs() — Get the current array of mock DogData.
     *
     * @return array of DogData objects with current mock values
     */
    function getDogs() as Array<DogData> {
        return _dogs;
    }

    /**
     * getConnectionState() — Get the simulated connection state.
     *
     * @return one of the Constants.ANT_STATE_* values
     */
    function getConnectionState() as Number {
        return _connectionState;
    }

    /**
     * isActive() — Check if mock data generation is running.
     */
    function isActive() as Boolean {
        return _isActive;
    }

    /**
     * onMockUpdate() — Timer callback that updates mock dog data each second.
     *
     * Simulates realistic dog behavior:
     *   - Distances drift randomly (dogs wandering)
     *   - Directions change slowly (dogs moving around)
     *   - Duke goes ON POINT every ~30 seconds for ~5 seconds
     *   - Battery drains slowly over time
     *   - Connection transitions from searching → connected after 3 seconds
     */
    function onMockUpdate() as Void {
        _tickCount++;
        var now = Time.now().value();

        // Simulate connection establishment (searching → connected after 3 ticks)
        if (_connectionState == Constants.ANT_STATE_SEARCHING && _tickCount >= 3) {
            _connectionState = Constants.ANT_STATE_CONNECTED;
            System.println("DogTrackerMock: Connected to mock handheld");
        }

        // Don't update dog data while still "searching"
        if (_connectionState != Constants.ANT_STATE_CONNECTED) {
            return;
        }

        for (var i = 0; i < _dogs.size(); i++) {
            var dog = _dogs[i];
            dog.lastUpdateTime = now;

            // --- Distance drift ---
            // Random walk: change by -5 to +5 yards each second.
            // This simulates a dog wandering in the field.
            var distChange = (Math.rand() % 11) - 5;
            dog.distanceYards = dog.distanceYards + distChange;

            // Clamp distance to reasonable range
            if (dog.distanceYards < 5) { dog.distanceYards = 5; }
            if (dog.distanceYards > 300) { dog.distanceYards = 300; }

            // --- Direction drift ---
            // Slowly rotate the bearing (dogs circle around the hunter)
            var dirChange = ((Math.rand() % 21) - 10).toDouble();
            dog.direction = dog.direction + dirChange;

            // Normalize to 0-360
            while (dog.direction >= 360.0d) { dog.direction = dog.direction - 360.0d; }
            while (dog.direction < 0.0d) { dog.direction = dog.direction + 360.0d; }

            // --- Status changes ---
            // Dog 3 (Duke) goes ON POINT periodically to test alerts.
            // This triggers the haptic vibration and red background in the UI.
            if (i == 2) {
                // Every 30 seconds, Duke goes ON POINT
                if (_tickCount % 30 == 15) {
                    dog.status = Constants.DOG_STATUS_ON_POINT;
                    dog.distanceYards = 60; // Dog stops at medium distance
                } else if (_tickCount % 30 == 20) {
                    // After 5 seconds of pointing, go back to moving
                    dog.status = Constants.DOG_STATUS_MOVING;
                }
            }

            // Dog 2 (Belle) alternates between moving and stationary
            if (i == 1) {
                if (_tickCount % 20 < 10) {
                    dog.status = Constants.DOG_STATUS_STATIONARY;
                } else {
                    dog.status = Constants.DOG_STATUS_MOVING;
                }
            }

            // --- Battery drain ---
            // Very slow drain: lose 1% every 60 ticks (1 minute)
            if (_tickCount % 60 == 0 && dog.batteryPercent > 0) {
                dog.batteryPercent--;
            }
        }
    }
}

/**
 * DogMockTimerHelper — Helper class to provide a timer callback for DogTrackerMock.
 *
 * WHY: Monkey C modules don't have 'self', so they can't use method() to create
 * Method references for timer callbacks. This helper class wraps the timer
 * and delegates the callback to the DogTrackerMock module.
 */
class DogMockTimerHelper {

    var _timer as Timer.Timer?;

    function initialize() {
    }

    /**
     * start() — Start the 1-second update timer.
     */
    function start() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    /**
     * stop() — Stop the update timer.
     */
    function stop() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    /**
     * onTick() — Timer callback that delegates to the mock module.
     */
    function onTick() as Void {
        DogTrackerMock.onMockUpdate();
    }
}
