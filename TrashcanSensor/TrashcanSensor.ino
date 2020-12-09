// Uses provided patch.
# include "WiFiEsp.h"

// Emulate Serial1 on pins 6/7 if not present
# ifndef HAVE_HWSERIAL1
# include "SoftwareSerial.h"
SoftwareSerial Serial1(11, 10);
# endif

// Digital
# define LED_1 2
# define LED_2 3
# define LED_3 4
# define LED_4 5
# define LED_5 6
# define LED_6 7
# define LED_7 8
# define LED_8 9

// Analog... 2M Ohm Resistor
# define LIGHT_SENSOR_1 0
# define LIGHT_SENSOR_2 1

// Other
# define CALIBRATION_TIME_MS 10000
# define LEVEL_CALIBRATION_TIME_MS 3000
# define LIGHT_MAPPED_MINIMUM 0
# define LIGHT_MAPPED_MAXIMUM 1023
# define LEVEL_COUNT 4
# define CHECK_FREQUENCY_MS 14400000 // 4 hours
# define LEVEL_CHECK_TIME_MS 3000
# define LIGHT_THRESHOLD_1 0.7
# define LIGHT_THRESHOLD_2 0.7
# define DEVICE_SERIAL "TRASHCAN_SENSOR_2"
# define THRESHOLD_MINIMUM_COUNT 3

int lightSensor1Minimum = 10000;
int lightSensor1Maximum = -1;

int lightSensor2Minimum = 10000;
int lightSensor2Maximum = -1;

// Storing the light readings from both sensors which are on both sides fo the lid.
//  Index 0 is light sensor 0 and index 1 is light sensor 1 and then it repeats for each level.
int levelThresholds[LEVEL_COUNT * 2];

int LEDS[8] = {LED_1, LED_2, LED_3, LED_4, LED_5, LED_6, LED_7, LED_8};

// WiFi
char ssid[] = "E76FBA";
char pass[] = "2DV333UK04446";
int wifiStatus = WL_IDLE_STATUS;
char server[] = "54.68.34.145";
int port = 80;

WiFiEspClient client;

void setup() {
    Serial.begin(115200);

    // Initialize serial for ESP module.
    Serial1.begin(115200);

    // Initialize ESP module.
    WiFi.init(&Serial1);

    // Check for the presence of the shield.
    if (WiFi.status() == WL_NO_SHIELD) {
        Serial.println("WiFi shield not present.");
        // Don't continue.
        while (true);
    }
    
    // Attempt to connect to WiFi network.
    while (wifiStatus != WL_CONNECTED) {
        Serial.print("Attempting to connect to WPA SSID: ");
        Serial.println(ssid);
        // Connect to WPA/WPA2 network
        wifiStatus = WiFi.begin(ssid, pass);
    }
    Serial.println("Connected to the network.");
    delay(2000);
    registerDevice(DEVICE_SERIAL, LEVEL_COUNT);

    Serial.println();
    Serial.println("Calibrating...");

    // Setup the LED pins.
    pinMode(LED_1, OUTPUT);
    pinMode(LED_2, OUTPUT);
    pinMode(LED_3, OUTPUT);
    pinMode(LED_4, OUTPUT);
    pinMode(LED_5, OUTPUT);
    pinMode(LED_6, OUTPUT);
    pinMode(LED_7, OUTPUT);
    pinMode(LED_8, OUTPUT);

    // Calibrate the sensor. Have the LEDs off half the time and on the other
    //  in order to calibrate.
    unsigned long time = millis();
    unsigned long ledsOn = false;

    while (millis() - time < CALIBRATION_TIME_MS) {
        // Check light reading.
        int currentLight1 = analogRead(LIGHT_SENSOR_1);
        int currentLight2 = analogRead(LIGHT_SENSOR_2);

        // Set the minimum and maximum values.
        lightSensor1Minimum = min(lightSensor1Minimum, currentLight1);
        lightSensor1Maximum = max(lightSensor1Maximum, currentLight1);

        lightSensor2Minimum = min(lightSensor2Minimum, currentLight2);
        lightSensor2Maximum = max(lightSensor2Maximum, currentLight2);

        // Check if the 50% of time has passed to switch LEDs on.
        if (!ledsOn && (millis() - time) >= (CALIBRATION_TIME_MS / 2)) {
            allLedOn();
            ledsOn = true;
        }
    }

    allLedOff();
    Serial.println("Determining thresholds for each level.");

    for (int level = 0; level < LEVEL_COUNT; level++) {
        int currentBaseIndex = level * 2;
        calibrateLevel(level, LEDS[currentBaseIndex], LEDS[currentBaseIndex + 1]);
    }

    Serial.print("lightSensor1Minimum: ");
    Serial.println(lightSensor1Minimum);
    Serial.print("lightSensor1Maximum: ");
    Serial.println(lightSensor1Maximum);
    Serial.print("lightSensor2Minimum: ");
    Serial.println(lightSensor2Minimum);
    Serial.print("lightSensor2Maximum: ");
    Serial.println(lightSensor2Maximum);
    Serial.println("Done calibrating.");
}

void loop() {
    Serial.println("Checking trash levels...");
    int currentLevel = 0;

    // Keeps going until the threshold is met for both sensors. When it stops the "currentLevel" is the last full
    //  level. So if it stops at 0 then the trash can is empty. If it stops at "LEVEL_COUNT" then it's full.
    for (; currentLevel < LEVEL_COUNT; currentLevel++) {
        int currentBaseIndex = currentLevel * 2;
        if (levelCheck(currentLevel, LEDS[currentBaseIndex], LEDS[currentBaseIndex + 1], LIGHT_THRESHOLD_1, LIGHT_THRESHOLD_2)) {
            break;
        }
    }

    reportFindings(DEVICE_SERIAL, currentLevel);
    Serial.println("Checked trash levels.");
    Serial.println("Going to sleep.");
    Serial.println();

    // A battery powered version could use one of the timed deep sleep methods.
    delay(CHECK_FREQUENCY_MS);
}

void allLedOn() {
    digitalWrite(LED_1, HIGH);
    digitalWrite(LED_2, HIGH);
    digitalWrite(LED_3, HIGH);
    digitalWrite(LED_4, HIGH);
    digitalWrite(LED_5, HIGH);
    digitalWrite(LED_6, HIGH);
    digitalWrite(LED_7, HIGH);
    digitalWrite(LED_8, HIGH);
}

void allLedOff() {
    digitalWrite(LED_1, LOW);
    digitalWrite(LED_2, LOW);
    digitalWrite(LED_3, LOW);
    digitalWrite(LED_4, LOW);
    digitalWrite(LED_5, LOW);
    digitalWrite(LED_6, LOW);
    digitalWrite(LED_7, LOW);
    digitalWrite(LED_8, LOW);
}

void calibrateLevel(int level, int ledPin1, int ledPin2) {
    digitalWrite(ledPin1, HIGH);
    digitalWrite(ledPin2, HIGH);

    // Set the initial values for the level.
    int currentBaseIndex = level * 2;
    levelThresholds[currentBaseIndex] = 0;
    levelThresholds[currentBaseIndex + 1] = 0;

    unsigned long time = millis();
    while (millis() - time < LEVEL_CALIBRATION_TIME_MS) {
        // Check light reading.
        int lightReading[2];
        lightReading[0] = map(analogRead(LIGHT_SENSOR_1), lightSensor1Minimum, lightSensor1Maximum, LIGHT_MAPPED_MINIMUM, LIGHT_MAPPED_MAXIMUM);
        lightReading[1] = map(analogRead(LIGHT_SENSOR_2), lightSensor2Minimum, lightSensor2Maximum, LIGHT_MAPPED_MINIMUM, LIGHT_MAPPED_MAXIMUM);
        
        // Set the maximum values.
        levelThresholds[currentBaseIndex] = max(levelThresholds[currentBaseIndex], lightReading[0]);
        levelThresholds[currentBaseIndex + 1] = max(levelThresholds[currentBaseIndex + 1], lightReading[1]);
    }

    digitalWrite(ledPin1, LOW);
    digitalWrite(ledPin2, LOW);
}

bool levelCheck(int level, int ledPin1, int ledPin2, float thresholdPercent1, float thresholdPercent2) {
    int thresholdMetCount = 0;
    bool thresholdMet = false;
    int currentBaseIndex = level * 2;

    digitalWrite(ledPin1, HIGH);
    digitalWrite(ledPin2, HIGH);

    unsigned long time = millis();
    while (millis() - time < LEVEL_CHECK_TIME_MS) {
        // Check light reading.
        int lightReading[2];
        lightReading[0] = map(analogRead(LIGHT_SENSOR_1), lightSensor1Minimum, lightSensor1Maximum, LIGHT_MAPPED_MINIMUM, LIGHT_MAPPED_MAXIMUM);
        lightReading[1] = map(analogRead(LIGHT_SENSOR_2), lightSensor2Minimum, lightSensor2Maximum, LIGHT_MAPPED_MINIMUM, LIGHT_MAPPED_MAXIMUM);
      
        // Both sensors must meet the threshold for it to be satisfied.
        if (lightReading[0] >= levelThresholds[currentBaseIndex] * thresholdPercent1 && lightReading[1] >= levelThresholds[currentBaseIndex + 1] * thresholdPercent2) {
            thresholdMetCount++;
        }

        if (thresholdMetCount >= THRESHOLD_MINIMUM_COUNT) {
          thresholdMet = true;
          break;
        }

        delay(500);
    }

    digitalWrite(ledPin1, LOW);
    digitalWrite(ledPin2, LOW);

    return thresholdMet;
}

void sendRequest(char* getRequest) {
    if (!client.connected()) {
        Serial.println("Starting connection to server...");
        client.connect(server, port);
    }
    Serial.println("Connected to server");
    // Make a HTTP request
    client.print(getRequest);
    delay(500);
    while (client.available()) {
        char c = client.read();
        Serial.write(c);
    }
}

void registerDevice(char* serialNumber, int totalLevels) {
    char getRequest[300];

    Serial.println("Registering device...");

    // Make a HTTP request
    sprintf(getRequest, "PUT /register?deviceId=%s&totalLevels=%d HTTP/1.1\r\nHost: %s:%d\r\nConnection: close\r\n\r\n", serialNumber, totalLevels, server, port);
    sendRequest(getRequest);
}

void reportFindings(char* serialNumber, int fullLevel) {
    char getRequest[300];

    Serial.println("Reporting findings...");
    
    // Make a HTTP request
    sprintf(getRequest, "PUT /report?deviceId=%s&fillLevel=%d HTTP/1.1\r\nHost: %s:%d\r\nConnection: close\r\n\r\n", serialNumber, fullLevel, server, port);
    sendRequest(getRequest);
}
