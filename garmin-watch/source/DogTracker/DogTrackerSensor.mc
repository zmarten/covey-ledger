import Toybox.Ant;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Sensor;
import Toybox.Timer;

const PAIRED_DEVICE_STORE_KEY = "paired_ant_device_number";

function loadPairedDeviceNumber() as Number {
    var stored = Application.Storage.getValue(PAIRED_DEVICE_STORE_KEY);
    if (stored != null) {
        return stored as Number;
    }
    return 0;
}

function savePairedDeviceNumber(deviceNumber as Number) as Void {
    Application.Storage.setValue(PAIRED_DEVICE_STORE_KEY, deviceNumber);
}

function clearPairedDeviceNumber() as Void {
    Application.Storage.deleteValue(PAIRED_DEVICE_STORE_KEY);
}

/**
 * DogTrackerSensor — Real ANT+ connection to Garmin Alpha/Astro handheld.
 *
 * Opens an ANT+ Generic Channel configured to receive dog tracking data
 * broadcast by a Garmin Alpha or Astro handheld device. The handheld
 * must have "Broadcast Dog Data" enabled in its settings.
 *
 * PROTOCOL NOTES:
 *   The Alpha/Astro broadcasts dog data using a proprietary ANT+ protocol
 *   that is NOT officially documented by Garmin. The implementation here
 *   is based on community reverse engineering efforts, primarily:
 *     - ekutter's Dog Tracker app (https://ekutter.github.io)
 *     - Garmin developer forum discussions
 *     - thisisant.com protocol documentation (registration required)
 *
 *   Because the protocol is reverse-engineered, some packet parsing may
 *   be incorrect. DogTrackerMock remains available for isolated development
 *   and testing, but production views should read from this sensor class.
 *   See ISSUES.md for protocol unknowns.
 *
 * CHANNEL SETUP:
 *   - Type: Slave Receive (we listen for handheld broadcasts)
 *   - Network: ANT+ (NETWORK_PLUS)
 *   - Device search uses wildcards (device number 0) for auto-discovery
 *   - Once a handheld is found, its device number is stored for reconnection
 *
 * DATA FLOW:
 *   Handheld broadcasts → ANT+ radio → onMessage() callback → parse packets
 *   → update DogData objects → MainView/MapView read updated data
 *
 * SYSTEM 8 NOTE:
 *   On System 8 devices (Fenix 8, etc.), opening ANT channels for sensors
 *   that aren't natively paired triggers a security warning dialog.
 *   To avoid this, we implement DogTrackerPairingDelegate (SensorDelegate)
 *   and return it from the app's getSensorDelegate() method. This allows
 *   the system to manage pairing through its native UI.
 */
class DogTrackerSensor {

    // =========================================================================
    // ANT+ CHANNEL CONFIGURATION
    // These values define how we communicate with the Alpha/Astro.
    // Some are based on community research and may need adjustment
    // with real hardware. See ISSUES.md for protocol documentation status.
    // =========================================================================

    // Device type for dog tracker broadcasts.
    // 0 = wildcard (search for any device type during discovery)
    const DEVICE_TYPE = 0;

    // Radio frequency offset from 2400 MHz.
    // ANT+ standard frequency is 57 (2457 MHz).
    // Dog tracker may use a different frequency — start with ANT+ standard.
    const RADIO_FREQUENCY = 57;

    // Message period (channel period).
    // 4096 = ~8 messages/second. Common for real-time tracking.
    // This may need tuning based on actual Alpha/Astro behavior.
    const MESSAGE_PERIOD = 4096;

    // Transmission type (0 = wildcard for discovery)
    const TRANSMISSION_TYPE = 0;

    // Search timeout in 2.5-second increments.
    // 12 = 30 seconds of searching before timeout.
    const SEARCH_TIMEOUT_LOW = 12;
    const SEARCH_TIMEOUT_HIGH = 2;

    // =========================================================================
    // PROTOCOL PAGE IDS (best-effort, based on community research)
    // The handheld sends 8-byte data pages with different page IDs.
    // Each page type carries different information about the dogs.
    // =========================================================================

    // Dog status/distance/direction data page
    const PAGE_DOG_DATA = 1;

    // Dog name data page (6 characters per packet)
    const PAGE_DOG_NAME = 2;

    // Dog color/metadata page
    const PAGE_DOG_COLOR = 3;

    // =========================================================================
    // INSTANCE VARIABLES
    // =========================================================================

    // The ANT Generic Channel for receiving handheld broadcasts.
    // null if the channel hasn't been opened or failed to acquire.
    var _channel as Ant.GenericChannel?;

    // Current connection state (IDLE, SEARCHING, CONNECTED, LOST)
    var _connectionState as Number = Constants.ANT_STATE_IDLE;

    // Dog data parsed from ANT+ packets.
    // Indexed by dog ID (from the ANT+ packet dog index field).
    // Up to 20 dogs supported.
    var _dogs as Array<DogData> = [] as Array<DogData>;

    // Device number of the connected handheld (for reconnection).
    // 0 = not yet discovered (using wildcard search).
    var _pairedDeviceNumber as Number = 0;

    // Counts how many raw payload samples we've logged for each page ID.
    // This keeps hardware-validation logging useful without flooding output.
    var _pageLogCounts as Dictionary = {} as Dictionary;

    /**
     * Constructor.
     */
    function initialize() {
        _pairedDeviceNumber = loadPairedDeviceNumber();
        _pageLogCounts = {} as Dictionary;
    }

    /**
     * open() — Open the ANT+ channel and begin searching for a handheld.
     *
     * Creates a Generic Channel configured as a slave receiver on the
     * ANT+ network. Uses wildcard device number for auto-discovery.
     * The channel will receive broadcast messages from any Alpha/Astro
     * handheld that has "Broadcast Dog Data" enabled.
     *
     * @return true if channel opened successfully, false if failed
     */
    function open() as Boolean {
        try {
            _pageLogCounts = {} as Dictionary;

            // Create a receive-only channel on the ANT+ network.
            // CHANNEL_TYPE_RX_NOT_TX = we're a slave that receives data.
            // NETWORK_PLUS = ANT+ network (most Garmin sensors use this).
            var chanAssign = new Ant.ChannelAssignment(
                Ant.CHANNEL_TYPE_RX_NOT_TX,
                Ant.NETWORK_PLUS
            );

            // Create the channel with our message handler callback.
            // The system calls onMessage() whenever data arrives.
            _channel = new Ant.GenericChannel(
                method(:onMessage),
                chanAssign
            );

            // Configure device search parameters.
            // Using wildcards (0) for device number and device type
            // so we can discover any compatible handheld nearby.
            var deviceCfg = new Ant.DeviceConfig({
                :deviceNumber => _pairedDeviceNumber, // 0 = wildcard search
                :deviceType => DEVICE_TYPE,
                :transmissionType => TRANSMISSION_TYPE,
                :messagePeriod => MESSAGE_PERIOD,
                :radioFrequency => RADIO_FREQUENCY,
                :searchTimeoutLowPriority => SEARCH_TIMEOUT_LOW,
                :searchTimeoutHighPriority => SEARCH_TIMEOUT_HIGH
            });
            _channel.setDeviceConfig(deviceCfg);

            // Open the channel — starts the ANT radio searching
            var opened = _channel.open();
            if (opened) {
                _connectionState = Constants.ANT_STATE_SEARCHING;
                logDebug("Channel opened, searching...");
            } else {
                _connectionState = Constants.ANT_STATE_IDLE;
                logDebug("Failed to open channel");
            }
            return opened;

        } catch (ex instanceof Ant.UnableToAcquireChannelException) {
            // No ANT channels available on the device.
            // This can happen if other apps are using all channels.
            logDebug("No ANT channels available");
            _connectionState = Constants.ANT_STATE_IDLE;
            return false;
        } catch (ex) {
            logDebug("Error opening channel: " + ex.getErrorMessage());
            _connectionState = Constants.ANT_STATE_IDLE;
            return false;
        }
    }

    /**
     * close() — Close the ANT+ channel and stop receiving data.
     *
     * Called when the hunt ends or the app is shutting down.
     * Properly releases the ANT channel resource.
     */
    function close() as Void {
        if (_channel != null) {
            _channel.close();
            _channel.release();
            _channel = null;
        }
        _connectionState = Constants.ANT_STATE_IDLE;
        logDebug("Channel closed");
    }

    /**
     * getDogs() — Get the current array of dog data from ANT+ packets.
     *
     * @return array of DogData objects parsed from ANT+ broadcasts
     */
    function getDogs() as Array<DogData> {
        return _dogs;
    }

    /**
     * getConnectionState() — Get the current ANT+ connection state.
     *
     * @return one of the Constants.ANT_STATE_* values
     */
    function getConnectionState() as Number {
        return _connectionState;
    }

    /**
     * onMessage() — ANT+ message callback.
     *
     * Called by the system whenever the ANT channel receives a message.
     * This is the core of the ANT+ integration — we parse the raw
     * 8-byte packets into structured DogData objects.
     *
     * Message types we handle:
     *   - BROADCAST_DATA (0x4E): Dog tracking data from handheld
     *   - CHANNEL_RESPONSE_EVENT: Channel state changes (closed, timeout)
     *   - CHANNEL_ID: Device identification (after connection)
     *
     * @param msg — the received ANT message
     */
    function onMessage(msg as Ant.Message) as Void {
        var payload = msg.getPayload();

        if (msg.messageId == Ant.MSG_ID_BROADCAST_DATA) {
            // Received dog tracking data from the handheld!
            // This means we're connected and receiving.
            _connectionState = Constants.ANT_STATE_CONNECTED;

            // Store the device number for reconnection
            if (msg.deviceNumber != null && _pairedDeviceNumber == 0) {
                _pairedDeviceNumber = msg.deviceNumber;
                savePairedDeviceNumber(_pairedDeviceNumber);
                logDebug("Paired with device #" + _pairedDeviceNumber);
            } else if (msg.deviceNumber != null && _pairedDeviceNumber != msg.deviceNumber) {
                _pairedDeviceNumber = msg.deviceNumber;
                savePairedDeviceNumber(_pairedDeviceNumber);
                logDebug("Switched paired device to #" + _pairedDeviceNumber);
            }

            // Parse the data page based on page ID (first byte)
            parseBroadcastData(payload);

        } else if (msg.messageId == Ant.MSG_ID_CHANNEL_RESPONSE_EVENT) {
            // Channel event — check for important state changes
            if (payload[0] == Ant.MSG_ID_RF_EVENT) {
                var eventCode = payload[1];

                if (eventCode == Ant.MSG_CODE_EVENT_RX_SEARCH_TIMEOUT) {
                    // Search timed out — no handheld found nearby
                    _connectionState = Constants.ANT_STATE_LOST;
                    logDebug("Search timeout - no handheld found");

                    // Try reopening the channel to continue searching
                    if (_channel != null) {
                        _channel.open();
                        _connectionState = Constants.ANT_STATE_SEARCHING;
                    }

                } else if (eventCode == Ant.MSG_CODE_EVENT_CHANNEL_CLOSED) {
                    // Channel was closed (by system or signal loss)
                    _connectionState = Constants.ANT_STATE_LOST;
                    logDebug("Channel closed by event, attempting reopen");

                    // Auto-reopen for reconnection
                    if (_channel != null) {
                        _channel.open();
                        _connectionState = Constants.ANT_STATE_SEARCHING;
                    }

                } else if (eventCode == Ant.MSG_CODE_EVENT_RX_FAIL) {
                    // Missed a message — normal, happens with RF interference.
                    // Don't change state — we'll recover on next good message.
                }
            }
        }
    }

    /**
     * parseBroadcastData() — Parse an 8-byte ANT+ data page from the handheld.
     *
     * PROTOCOL CAVEAT:
     *   This parsing is based on community reverse engineering of the
     *   Alpha/Astro broadcast format. The actual byte layout may differ.
     *   If parsing produces garbage data, the protocol constants at the
     *   top of this file need to be updated. See ISSUES.md for details.
     *
     * Page types (byte 0):
     *   PAGE_DOG_DATA (1): Distance, direction, status for one dog
     *   PAGE_DOG_NAME (2): 6 characters of a dog's name
     *   PAGE_DOG_COLOR (3): Collar color and metadata
     *
     * @param payload — 8-byte array from the ANT+ message
     */
    function parseBroadcastData(payload as Array) as Void {
        if (payload.size() < 8) { return; }

        var pageId = payload[0] as Number;
        logPayloadSample(pageId, payload);

        if (pageId == PAGE_DOG_DATA) {
            parseDogDataPage(payload);
        } else if (pageId == PAGE_DOG_NAME) {
            parseDogNamePage(payload);
        } else if (pageId == PAGE_DOG_COLOR) {
            parseDogColorPage(payload);
        } else {
            logDebug("Unknown page " + pageId.format("%d") + " payload=" + payloadToHex(payload));
        }
    }

    /**
     * parseDogDataPage() — Parse a dog distance/direction/status packet.
     *
     * ESTIMATED BYTE LAYOUT (needs verification with real hardware):
     *   Byte 0: Page ID (0x01)
     *   Byte 1: Dog index (0-19)
     *   Byte 2-3: Distance in meters (uint16, little-endian)
     *   Byte 4-5: Bearing in degrees * 10 (uint16, little-endian)
     *   Byte 6: Status flags (moving/stationary/on-point/treed/etc.)
     *   Byte 7: Signal quality (0-100) or battery level
     */
    function parseDogDataPage(payload as Array) as Void {
        var dogIndex = payload[1] as Number;

        // Ensure we have a DogData for this dog index
        var dog = getOrCreateDog(dogIndex);
        var previousStatus = dog.status;

        // Parse distance (bytes 2-3, little-endian, in meters)
        var distMeters = ((payload[3] as Number) << 8) | (payload[2] as Number);
        dog.distanceYards = (distMeters.toDouble() * Constants.METERS_TO_YARDS).toNumber();

        // Parse bearing (bytes 4-5, little-endian, in degrees * 10)
        var bearingRaw = ((payload[5] as Number) << 8) | (payload[4] as Number);
        dog.direction = bearingRaw.toDouble() / 10.0d;

        // Parse status (byte 6)
        var statusByte = payload[6] as Number;
        dog.status = mapStatusByte(statusByte);

        // Parse signal quality or battery (byte 7)
        dog.signalQuality = payload[7] as Number;
        if (dog.signalQuality > 100) { dog.signalQuality = 100; }

        // Update timestamp
        dog.lastUpdateTime = Time.now().value();

        if (previousStatus != dog.status) {
            logDebug(
                "Dog #" + dogIndex.format("%d") +
                " status " + statusName(previousStatus) +
                " -> " + statusName(dog.status) +
                " (raw=" + statusByte.format("%d") +
                ", distYd=" + dog.distanceYards.format("%d") +
                ", bearing=" + dog.direction.format("%.1f") +
                ", signal=" + dog.signalQuality.format("%d") + ")"
            );
        }
    }

    /**
     * parseDogNamePage() — Parse a dog name packet.
     *
     * ESTIMATED BYTE LAYOUT:
     *   Byte 0: Page ID (0x02)
     *   Byte 1: Dog index (0-19)
     *   Bytes 2-7: Name characters (6 bytes of ASCII, null-padded)
     */
    function parseDogNamePage(payload as Array) as Void {
        var dogIndex = payload[1] as Number;
        var dog = getOrCreateDog(dogIndex);

        // Extract name characters (bytes 2-7)
        var nameChars = [] as Array<Char>;
        for (var i = 2; i < 8; i++) {
            var ch = payload[i] as Number;
            if (ch == 0) { break; } // Null terminator
            nameChars.add(ch.toChar());
        }

        if (nameChars.size() > 0) {
            var nameStr = "";
            for (var i = 0; i < nameChars.size(); i++) {
                nameStr += nameChars[i];
            }
            if (!dog.name.equals(nameStr)) {
                dog.name = nameStr;
                logDebug("Dog #" + dogIndex.format("%d") + " name=" + nameStr);
            }
        }
    }

    /**
     * parseDogColorPage() — Parse a dog color/metadata packet.
     *
     * ESTIMATED BYTE LAYOUT:
     *   Byte 0: Page ID (0x03)
     *   Byte 1: Dog index (0-19)
     *   Byte 2: Collar color index
     *   Byte 3: Battery percent (0-100)
     *   Bytes 4-7: Reserved / additional metadata
     */
    function parseDogColorPage(payload as Array) as Void {
        var dogIndex = payload[1] as Number;
        var dog = getOrCreateDog(dogIndex);

        dog.color = payload[2] as Number;
        dog.batteryPercent = payload[3] as Number;
        if (dog.batteryPercent > 100) { dog.batteryPercent = 100; }
        logDebug(
            "Dog #" + dogIndex.format("%d") +
            " color=" + dog.color.format("%d") +
            " battery=" + dog.batteryPercent.format("%d")
        );
    }

    /**
     * getOrCreateDog() — Find an existing DogData by index or create a new one.
     *
     * Dogs are dynamically added as we receive their data packets.
     * Up to 20 dogs can be tracked (Constants.MAX_DOGS_DISPLAY).
     *
     * @param index — the dog index from the ANT+ packet
     * @return the DogData for this dog
     */
    function getOrCreateDog(index as Number) as DogData {
        // Search for existing dog with this index
        for (var i = 0; i < _dogs.size(); i++) {
            if (_dogs[i].id == index) {
                return _dogs[i];
            }
        }

        // Dog not found — create a new one
        var dog = new DogData("Dog " + (index + 1), index);
        if (_dogs.size() < Constants.MAX_DOGS_DISPLAY) {
            _dogs.add(dog);
            logDebug("Discovered dog slot #" + index.format("%d"));
        }
        return dog;
    }

    /**
     * mapStatusByte() — Convert the ANT+ status byte to our status enum.
     *
     * The actual status byte values from the Alpha/Astro are not definitively
     * known. This mapping is a best guess based on community research.
     *
     * @param statusByte — raw status byte from ANT+ packet
     * @return one of the Constants.DOG_STATUS_* values
     */
    function mapStatusByte(statusByte as Number) as Number {
        // Best-effort mapping (needs verification with real hardware)
        switch (statusByte) {
            case 0: return Constants.DOG_STATUS_MOVING;
            case 1: return Constants.DOG_STATUS_STATIONARY;
            case 2: return Constants.DOG_STATUS_ON_POINT;
            case 3: return Constants.DOG_STATUS_TREED;
            case 4: return Constants.DOG_STATUS_GPS_LOST;
            default: return Constants.DOG_STATUS_COMM_LOST;
        }
    }

    /**
     * logPayloadSample() — Log the first few packets of each page type.
     *
     * During real hardware validation this gives us raw bytes for page layouts
     * without overwhelming the device log on every broadcast message.
     */
    function logPayloadSample(pageId as Number, payload as Array) as Void {
        var count = _pageLogCounts.get(pageId);
        if (count == null) {
            count = 0;
        }

        if ((count as Number) < 3) {
            logDebug(
                "Sample page " + pageId.format("%d") +
                " payload=" + payloadToHex(payload)
            );
            _pageLogCounts.put(pageId, (count as Number) + 1);
        }
    }

    /**
     * payloadToHex() — Format an ANT payload as hex bytes for debug logs.
     */
    function payloadToHex(payload as Array) as String {
        var out = "";
        for (var i = 0; i < payload.size(); i++) {
            if (i > 0) {
                out += " ";
            }
            out += (payload[i] as Number).format("%02X");
        }
        return out;
    }

    /**
     * statusName() — Human-readable label for dog status debug logs.
     */
    function statusName(status as Number) as String {
        switch (status) {
            case Constants.DOG_STATUS_MOVING: return "MOVING";
            case Constants.DOG_STATUS_STATIONARY: return "STATIONARY";
            case Constants.DOG_STATUS_ON_POINT: return "ON_POINT";
            case Constants.DOG_STATUS_TREED: return "TREED";
            case Constants.DOG_STATUS_GPS_LOST: return "GPS_LOST";
            case Constants.DOG_STATUS_COMM_LOST: return "COMM_LOST";
            default: return "UNKNOWN";
        }
    }

    /**
     * logDebug() — Prefix sensor debug lines consistently.
     */
    function logDebug(message as String) as Void {
        System.println("DogTrackerSensor: " + message);
    }
}

/**
 * DogTrackerPairingDelegate — SensorDelegate for System 8 native pairing.
 *
 * On System 8 devices (Fenix 8 Solar, etc.), opening ANT channels for
 * sensors that aren't natively paired triggers a security warning dialog.
 * By implementing SensorDelegate and returning it from the app's
 * getSensorDelegate() method, we participate in the native pairing flow.
 *
 * This allows the system to manage the pairing UI, and our app gets
 * notified when a device is selected. We then use the paired device
 * number when opening our GenericChannel for a seamless experience.
 *
 * NOTE: This implementation is a framework stub. Full testing requires
 * real System 8 hardware and an Alpha/Astro handheld. See ISSUES.md.
 */
class DogTrackerPairingDelegate extends Sensor.SensorDelegate {

    const SCAN_TIMEOUT_MS = 10000;
    const PAIR_SCAN_DEVICE_TYPE = 0;
    const PAIR_SCAN_RADIO_FREQUENCY = 57;
    const PAIR_SCAN_MESSAGE_PERIOD = 4096;
    const PAIR_SCAN_TRANSMISSION_TYPE = 0;
    const PAIR_SCAN_TIMEOUT_LOW = 4;
    const PAIR_SCAN_TIMEOUT_HIGH = 1;

    var _scanChannel as Ant.GenericChannel?;
    var _scanTimer as Timer.Timer?;
    var _discoveredDevices as Array<Number> = [] as Array<Number>;

    /**
     * Constructor.
     */
    function initialize() {
        SensorDelegate.initialize();
        _scanChannel = null;
        _scanTimer = null;
        _discoveredDevices = [] as Array<Number>;
    }

    /**
     * pairingRequired() — Tell the system we need sensor pairing.
     *
     * Returning true makes our app appear in the system's sensor
     * pairing flow, allowing the user to pair their Alpha/Astro
     * handheld through the native UI.
     */
    function pairingRequired() as Boolean {
        return true;
    }

    /**
     * onScan() — System requests us to start scanning for devices.
     *
     * Called when the user enters the sensor pairing UI.
     * We should start scanning and call Sensor.notifyNewSensor()
     * for each compatible device found.
     *
     * @return true if scanning started successfully
     */
    function onScan() as Boolean {
        stopScan(false);
        _discoveredDevices = [] as Array<Number>;
        logPairing("Scan requested");

        try {
            var chanAssign = new Ant.ChannelAssignment(
                Ant.CHANNEL_TYPE_RX_NOT_TX,
                Ant.NETWORK_PLUS
            );
            _scanChannel = new Ant.GenericChannel(method(:onScanMessage), chanAssign);
            _scanChannel.setDeviceConfig(new Ant.DeviceConfig({
                :deviceNumber => 0,
                :deviceType => PAIR_SCAN_DEVICE_TYPE,
                :transmissionType => PAIR_SCAN_TRANSMISSION_TYPE,
                :messagePeriod => PAIR_SCAN_MESSAGE_PERIOD,
                :radioFrequency => PAIR_SCAN_RADIO_FREQUENCY,
                :searchTimeoutLowPriority => PAIR_SCAN_TIMEOUT_LOW,
                :searchTimeoutHighPriority => PAIR_SCAN_TIMEOUT_HIGH
            }));

            if (!_scanChannel.open()) {
                logPairing("Scan channel failed to open");
                stopScan(false);
                Sensor.notifyScanComplete();
                return false;
            }

            _scanTimer = new Timer.Timer();
            _scanTimer.start(method(:onScanTimeout), SCAN_TIMEOUT_MS, false);
            logPairing("ANT wildcard scan started");
            return true;
        } catch (ex) {
            logPairing("Scan failed: " + ex.getErrorMessage());
            stopScan(false);
            Sensor.notifyScanComplete();
            return false;
        }
    }

    /**
     * onPair() — System requests us to pair with a specific device.
     *
     * Called when the user selects a device from the pairing UI.
     * We should store the device number and use it when opening
     * our GenericChannel for reliable reconnection.
     *
     * @param sensor — the sensor info for the device to pair
     * @return true if pairing succeeded
     */
    function onPair(sensor as Sensor.SensorInfo) as Boolean {
        var deviceNumber = extractDeviceNumber(sensor);
        if (deviceNumber > 0) {
            savePairedDeviceNumber(deviceNumber);
            logPairing("Stored paired device #" + deviceNumber);
        } else {
            logPairing("Pair requested but device number was unavailable");
        }
        Sensor.notifyPairComplete(sensor);
        return true;
    }

    /**
     * onUnpair() — System requests us to unpair a device.
     *
     * @param sensor — the sensor info for the device to unpair
     * @return true if unpairing succeeded
     */
    function onUnpair(sensor as Sensor.SensorInfo) as Boolean {
        clearPairedDeviceNumber();
        logPairing("Unpair requested");
        Sensor.notifyUnpairComplete(sensor);
        return true;
    }

    function onScanMessage(msg as Ant.Message) as Void {
        if (msg.messageId != Ant.MSG_ID_BROADCAST_DATA || msg.deviceNumber == null) {
            return;
        }

        var deviceNumber = msg.deviceNumber as Number;
        if (hasDiscoveredDevice(deviceNumber)) {
            return;
        }

        _discoveredDevices.add(deviceNumber);
        var sensor = buildSensorInfo(deviceNumber, msg);
        logPairing("Discovered ANT device #" + deviceNumber);
        Sensor.notifyNewSensor(sensor, false);
    }

    function onScanTimeout() as Void {
        logPairing("Scan complete (" + _discoveredDevices.size().format("%d") + " device(s))");
        stopScan(true);
    }

    function stopScan(notifyComplete as Boolean) as Void {
        if (_scanTimer != null) {
            _scanTimer.stop();
            _scanTimer = null;
        }

        if (_scanChannel != null) {
            _scanChannel.close();
            _scanChannel.release();
            _scanChannel = null;
        }

        if (notifyComplete) {
            Sensor.notifyScanComplete();
        }
    }

    function hasDiscoveredDevice(deviceNumber as Number) as Boolean {
        for (var i = 0; i < _discoveredDevices.size(); i++) {
            if (_discoveredDevices[i] == deviceNumber) {
                return true;
            }
        }
        return false;
    }

    function buildSensorInfo(deviceNumber as Number, msg as Ant.Message) as Sensor.SensorInfo {
        var sensor = new Sensor.SensorInfo();
        sensor.name = "Alpha/Astro " + deviceNumber.format("%d");
        sensor.technology = Sensor.SENSOR_TECHNOLOGY_ANT;
        sensor.type = Sensor.SENSOR_GENERIC;
        sensor.enabled = true;
        sensor.data = {
            :antSerialNumber => deviceNumber,
            :antMessage => msg
        };
        return sensor;
    }

    function extractDeviceNumber(sensor as Sensor.SensorInfo) as Number {
        if (sensor.data != null) {
            var serial = sensor.data.get(:antSerialNumber);
            if (serial != null) {
                return serial as Number;
            }

            var antMsg = sensor.data.get(:antMessage);
            if (antMsg != null) {
                var msg = antMsg as Ant.Message;
                if (msg.deviceNumber != null) {
                    return msg.deviceNumber as Number;
                }
            }
        }
        return 0;
    }

    function logPairing(message as String) as Void {
        System.println("DogTrackerPairing: " + message);
    }
}
