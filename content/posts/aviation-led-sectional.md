---
title: LED Aviation Sectional 🗺️
description:
date: 2023-02-14
tldr: Build a map with colored LED's based on weather conditions at airports.
draft: false
og_image: /img/aviation-led-sectional/finished.png
tags: [aviation, arduino]
---

![Aviation Sectional](/img/aviation-led-sectional/finished.png)

This blog is typically about AWS and HPC however once and a while I get to talk about other stuff like my [50 States Project](https://thefiftyproject.com/) or this Aviation Sectional I built.

The idea was to build a map, known in aviation parlance as a sectional, that illuminated airports based on the current weather condition. In aviation there's different flight rules that apply when conditions are below certain thresholds. I'll save you all the details but just know green = good, blue is less so, red is more work and purple means you probably shouldn't be flying a small aircraft.

| **Name**      | **Description**                                      | **Color**      |
|---------------|------------------------------------------------------|----------------|
| VFR           | Green means Go                                       | Green          |
| MVFR          | Clouds < 3k feet or visibility < 5 SM                | Blue           |
| IFR           | Clouds < 1k feet or visibility < 3 SM                | Red            |
| LIFR          | Clouds < 500 feet or visbility < 1 SM                | Purple         |
| Windy         | Wind > 25kts                                         | Yellow         |
| Thunderstorms | Flashes white when thunderstorms are in the vicinity | Flashing White |

There's many guides online on how to build one of these and I chose to follow [Kyle Harmon's Guide](https://led-sectional.kyleharmon.com/). I then customized it with my own frame style.

## Build

## Supplies
* [MDF Board](https://www.homedepot.com/p/Handprint-1-8-in-x-2-ft-x-4-ft-Tempered-Hardboard-Actual-0-115-in-x-23-75-in-x-47-75-in-Project-Panel-109112/202585358)
* FAA Sectional
* 3M Super 77 Spray Adhesive
* 1x4" pine trim boards
* [WS2811 LED lights](https://www.amazon.com/Rextin-WS2811-Digital-Addressable-Waterproof/dp/B01AU6UG70/)
* [Arduino controller](https://led-sectional.kyleharmon.com/kit.html) from Kyle Harmon

## Building the map...

    1.    First measure and cut down the MDF board - pro tip: Home Depot will do this for you! You can even use the off cuts to practice glueing / drilling. The dimensions I used for the Alaska sectional are 31” x 17”

![Blank MDF](/img/aviation-led-sectional/blank_mdf.jpeg)


    2.    First glue the paper sectional to the MDF backing board by spraying the shiny side of the MDF backing board with Super 77 adhesive. Wait a minute until the glue becomes tacky before applying the paper over the board starting from one side moving to the other and carefully flattening down with a ruler. Leave about 1” overhang on the sides so you can cut it down later.

    3.    Check that each of the airports you want to install an LED on have FAA official Metars by typing in the airport code to [FAA Metar website](https://aviationweather.gov/data/metar/). Mark the airports you want to illuminate with a sharpie.

    4.    Drill out each of those airports carefully with a 5/16” bit. Clean the edges of the holes with a box cutter.

  ![Glue down sectional](/img/aviation-led-sectional/glue_sectional.jpg)

    5.    Route the WS2811 LED lights through each hole, skipping LED’s to add length between airports. I highly advise trying to keep the LED strand intact as opposed to creating wiring extensions between the LED’s since each extension requires 6 x soldering connections and takes a long time. The LED pack comes with 50 LED’s so if you’re judicious you won’t have to create any wiring harnesses. 

  {{< rawhtml >}}
<p align="center">
    <img src='/img/aviation-led-sectional/wiring.jpeg' alt='Wiring Sectional' style='border: 0px;' width='400px' />
</p>
{{< /rawhtml >}}

    6.    Once you’re happy with the LED layout hot glue the LED’s into place. You need to use a lot of hot glue to get them to sit properly.

## Building the frame...

To build the frame I used 1x4" finish quality pine from Home Depot joined together with a pocket holes. 

    1.    I used 4” x 1” finish quality pine boards to create a box that would enclose the MDF. First I measured 4 x pieces and cut them down to size, adding an additional 1.5” to the top pieces so they’d cover the edge (.75” x 2)

    2.    To secure the frame together I used pocket holes using a fancy kreg jig. You don't need a fancy one, the basic Kreg jig will do the same job. To get the pieces to set correctly I made a jig using clamps and spare wood, this ensured the edges lined up smoothly and the frame was square. Woodworkers probably know a better way to do this but this is what I was able to come up with. 

{{< rawhtml >}}
    <p align="center">
        <img src='/img/aviation-led-sectional/kreg.jpeg' alt='Wiring Sectional' style='border: 0px;' width='200px' />
        <img src='/img/aviation-led-sectional/frame.jpeg' alt='Frame' style='border: 0px;' width='200px' />
    </p>
{{< /rawhtml >}}

    3. After securing the frame together, I 


## Software

The following instructions assume you've followed his build guide and are now ready to flash the software on the arduino.

### A. Download Arduino

1. First Download the Arduino IDE: https://www.arduino.cc/en/software
2. Once you've opened it, paste in the code linked below in [02-led-sectional.ino](#file-02-led-sectional-ino)

That's it! We'll talk about how to update the different parameters after we've installed the dependency libraries.

### B. Download Dependency Libraries

* Now we'll setup the [esp8266 library](https://arduino-esp8266.readthedocs.io/en/3.0.2/installing.html#instructions), this includes the wifi drivers for the board.
* We'll also install the [FastLED](http://fastled.io/) library which controls the color of the LED lights.

1. Open the Arduino IDE and click **File** > **Preferences**. Under the **Additional Board Manager URLs** paste in the following URL:

```
https://arduino.esp8266.com/stable/package_esp8266com_index.json
```
2. Click **Ok** to save
3. Click **Tools** > **Boards:** > **Board Manager**
4. Search `esp8266`
5. On the lower left, select the **2.7.4** version. Click install.
6. Also in Boards Manager, Search for the `Fast LED` Library. Install the latest version.

### C. Install CH340G Library

If you're using Windows, the CH340G Library is needed for Arduino to interface with the Board. Mac users can skip this step.

1. Visit the link: https://www.wemos.cc/en/latest/ch340_driver.html and download the correct version for your computer.
2. Unzip the file (on windows this is right click > Extract All) and double click on the SETUP file to execute it.
3. It'll pop open and window and click **Install**

### D. Update Wifi

Update line 20 & 21 of the [02-led-sectional.ino](#file-02-led-sectional-ino) file in the arduino IDE. Update the ssid to the **Name** of your wifi network and **pass** to the password.

```ino
const char ssid[] = "Wifi-123"; // your network SSID (name)
const char pass[] = "Password123"; // your network password (use for WPA, or use as key for WEP)
```

Now we'll click on the checkmark (verify) to compile the `led-sectional.ino` code. This should proceed without any warnings.

1. Under **Tools** > **Ports** Look at the Ports that show up. In my case that was `COM3, COM4, COM5, COM5, COM6`.
2. Plug in the Arduino via a micro usb cable.
3. Look again at the ports that show up, there should be one additional port i.e. `COM7`, select that one.
4. Click the arrow (upload) button to compile and upload the board.

That's it! If everything went correctly the LED's should glow, yellow, then purple, then change to METAR colors once the board is connected.

### The Code

```ino
#include <ESP8266WiFi.h>
#include <FastLED.h>
#include <vector>
using namespace std;

#define FASTLED_ESP8266_RAW_PIN_ORDER

#define NUM_AIRPORTS 80 // This is really the number of LEDs
#define WIND_THRESHOLD 25 // Maximum windspeed for green, otherwise the LED turns yellow
#define LOOP_INTERVAL 5000 // ms - interval between brightness updates and lightning strikes
#define DO_LIGHTNING true // Lightning uses more power, but is cool.
#define DO_WINDS true // color LEDs for high winds
#define REQUEST_INTERVAL 900000 // How often we update. In practice LOOP_INTERVAL is added. In ms (15 min is 900000)

#define USE_LIGHT_SENSOR false // Set USE_LIGHT_SENSOR to true if you're using any light sensor.
// Set LIGHT_SENSOR_TSL2561 to true if you're using a TSL2561 digital light sensor.
// Kits shipped after March 1, 2019 have a digital light sensor. Setting this to false assumes an analog light sensor.
#define LIGHT_SENSOR_TSL2561 false

const char ssid[] = "Wifi-123"; // your network SSID (name)
const char pass[] = "Password123"; // your network password (use for WPA, or use as key for WEP)

// Define the array of leds
CRGB leds[NUM_AIRPORTS];
#define DATA_PIN    14 // Kits shipped after March 1, 2019 should use 14. Earlier kits us 5.
#define LED_TYPE    WS2811
#define COLOR_ORDER RGB
#define BRIGHTNESS 20 // 20-30 recommended. If using a light sensor, this is the initial brightness on boot.

/* This section only applies if you have an ambient light sensor connected */
#if USE_LIGHT_SENSOR
/* The sketch will automatically scale the light between MIN_BRIGHTNESS and
MAX_BRIGHTNESS on the ambient light values between MIN_LIGHT and MAX_LIGHT
Set MIN_BRIGHTNESS and MAX_BRIGHTNESS to the same value to achieve a simple on/off effect. */
#define MIN_BRIGHTNESS 20 // Recommend values above 4 as colors don't show well below that
#define MAX_BRIGHTNESS 20 // Recommend values between 20 and 30

// Light values are a raw reading for analog and lux for digital
#define MIN_LIGHT 16 // Recommended default is 16 for analog and 2 for lux
#define MAX_LIGHT 30 // Recommended default is 30 to 40 for analog and 20 for lux

#if LIGHT_SENSOR_TSL2561
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2561_U.h>
#include <Wire.h>
Adafruit_TSL2561_Unified tsl = Adafruit_TSL2561_Unified(TSL2561_ADDR_FLOAT, 12345);
#else
#define LIGHTSENSORPIN A0 // A0 is the only valid pin for an analog light sensor
#endif

#endif
/* ----------------------------------------------------------------------- */

std::vector<unsigned short int> lightningLeds;
std::vector<String> airports({
  "KBLI", // 1 order of LEDs, starting with 1 should be KKIC; use VFR, WVFR, MVFR, IFR, LIFR for key; NULL for no airport
  "KORS", // 2
  "KFHR", // 3
  "CYYJ", // 4
  "CYWH", // 5
  "KCLM", // 6
  "KNOW", // 7
  "KUIL", // 8
  "K0S9", // 9
  "KNUW", // 10
  "KBVS", // 11
  "KAWO", // 12
  "KPAE", // 13
  "NULL", // 14
  "KBFI", // 15
  "KRNT", // 16
  "KSEA", // 17
  "KPWT", // 18
  "KTIW", // 19
  "KHQM", // 20
  "KSHN", // 21
  "KOLM", // 22
  "KGRF", // 23
  "KTCM", // 24
  "KPLU", // 25
  "NULL", // 26
  "KSMP", // 27
  "NULL", // 28
  "KELN", // 29
  "NULL", // 30
  "KEAT", // 31
  "NULL", // 32
  "KEPH", // 33
  "KMWH", // 34
  "KPUW", // 35
  "KSKA", // 36
  "KGEG", // 37
  "KSFF", // 38
  "KDEW", // 39
  "NULL", // 40
  "KCOE", // 41
  "NULL", // 42
  "KSZT", // 43
  "K63S", // 44
  "NULL", // 45
  "NULL", // 46
  "NULL", // 47
  "KOMK", // 48
  "NULL", // 49
  "KS52", // 50
  "NULL", // 51
  "NULL", // 52
  "NULL", // 53
  "NULL", // 54
  "NULL", // 55
  "NULL", // 56
  "NULL", // 57
  "NULL", // 58
  "NULL", // 59
  "NULL", // 60
  "NULL", // 61
  "NULL", // 62
  "NULL", // 63
  "NULL", // 64
  "NULL", // 65
  "NULL", // 66
  "NULL", // 67
  "NULL", // 68
  "NULL", // 69
  "NULL", // 70
  "NULL", // 71
  "NULL", // 72
  "NULL", // 73
  "NULL", // 74
  "NULL", // 75
  "NULL", // 76
  "NULL", // 77
  "NULL", // 78
  "NULL", // 79
  "NULL" // 80
});

#define DEBUG false

#define READ_TIMEOUT 15 // Cancel query if no data received (seconds)
#define WIFI_TIMEOUT 60 // in seconds
#define RETRY_TIMEOUT 15000 // in ms

#define SERVER "www.aviationweather.gov"
#define BASE_URI "/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&hoursBeforeNow=3&mostRecentForEachStation=true&stationString="

boolean ledStatus = true; // used so leds only indicate connection status on first boot, or after failure
int loops = -1;

int status = WL_IDLE_STATUS;

void setup() {
  //Initialize serial and wait for port to open:
  Serial.begin(74880);
  //pinMode(D1, OUTPUT); //Declare Pin mode
  //while (!Serial) {
  //    ; // wait for serial port to connect. Needed for native USB
  //}

  pinMode(LED_BUILTIN, OUTPUT); // give us control of the onboard LED
  digitalWrite(LED_BUILTIN, LOW);

  #if USE_LIGHT_SENSOR
  #if LIGHT_SENSOR_TSL2561
  Wire.begin(D2, D1);
  if(!tsl.begin()) {
    /* There was a problem detecting the TSL2561 ... check your connections */
    Serial.println("Ooops, no TSL2561 detected ... Check your wiring or I2C ADDR!");
  } else {
    tsl.enableAutoRange(true);
    tsl.setIntegrationTime(TSL2561_INTEGRATIONTIME_13MS);
  }
  #else
  pinMode(LIGHTSENSORPIN, INPUT);
  #endif
  #endif

  // Initialize LEDs
  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_AIRPORTS).setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(BRIGHTNESS);
}

#if USE_LIGHT_SENSOR
void adjustBrightness() {
  unsigned char brightness;
  float reading;

  #if LIGHT_SENSOR_TSL2561
  sensors_event_t event;
  tsl.getEvent(&event);
  reading = event.light;
  #else
  reading = analogRead(LIGHTSENSORPIN);
  #endif

  Serial.print("Light reading: ");
  Serial.print(reading);
  Serial.print(" raw, ");

  if (reading <= MIN_LIGHT) brightness = 0;
  else if (reading >= MAX_LIGHT) brightness = MAX_BRIGHTNESS;
  else {
    // Percentage in lux range * brightness range + min brightness
    float brightness_percent = (reading - MIN_LIGHT) / (MAX_LIGHT - MIN_LIGHT);
    brightness = brightness_percent * (MAX_BRIGHTNESS - MIN_BRIGHTNESS) + MIN_BRIGHTNESS;
  }

  Serial.print(brightness);
  Serial.println(" brightness");
  FastLED.setBrightness(brightness);
  FastLED.show();
}
#endif

void loop() {
  digitalWrite(LED_BUILTIN, LOW); // on if we're awake

  #if USE_LIGHT_SENSOR
  adjustBrightness();
  #endif

  int c;
  loops++;
  Serial.print("Loop: ");
  Serial.println(loops);
  unsigned int loopThreshold = 1;
  if (DO_LIGHTNING || USE_LIGHT_SENSOR) loopThreshold = REQUEST_INTERVAL / LOOP_INTERVAL;

  // Connect to WiFi. We always want a wifi connection for the ESP8266
  if (WiFi.status() != WL_CONNECTED) {
    if (ledStatus) fill_solid(leds, NUM_AIRPORTS, CRGB::Orange); // indicate status with LEDs, but only on first run or error
    FastLED.show();
    WiFi.mode(WIFI_STA);
    WiFi.hostname("LED Sectional " + WiFi.macAddress());
    //wifi_set_sleep_type(LIGHT_SLEEP_T); // use light sleep mode for all delays
    Serial.print("WiFi connecting..");
    WiFi.begin(ssid, pass);
    // Wait up to 1 minute for connection...
    for (c = 0; (c < WIFI_TIMEOUT) && (WiFi.status() != WL_CONNECTED); c++) {
      Serial.write('.');
      delay(1000);
    }
    if (c >= WIFI_TIMEOUT) { // If it didn't connect within WIFI_TIMEOUT
      Serial.println("Failed. Will retry...");
      fill_solid(leds, NUM_AIRPORTS, CRGB::Orange);
      FastLED.show();
      ledStatus = true;
      return;
    }
    Serial.println("OK!");
    if (ledStatus) fill_solid(leds, NUM_AIRPORTS, CRGB::Purple); // indicate status with LEDs
    FastLED.show();
    ledStatus = false;
  }

  // Do some lightning
  if (DO_LIGHTNING && lightningLeds.size() > 0) {
    std::vector<CRGB> lightning(lightningLeds.size());
    for (unsigned short int i = 0; i < lightningLeds.size(); ++i) {
      unsigned short int currentLed = lightningLeds[i];
      lightning[i] = leds[currentLed]; // temporarily store original color
      leds[currentLed] = CRGB::White; // set to white briefly
      Serial.print("Lightning on LED: ");
      Serial.println(currentLed);
    }
    delay(25); // extra delay seems necessary with light sensor
    FastLED.show();
    delay(25);
    for (unsigned short int i = 0; i < lightningLeds.size(); ++i) {
      unsigned short int currentLed = lightningLeds[i];
      leds[currentLed] = lightning[i]; // restore original color
    }
    FastLED.show();
  }

  if (loops >= loopThreshold || loops == 0) {
    loops = 0;
    if (DEBUG) {
      fill_gradient_RGB(leds, NUM_AIRPORTS, CRGB::Red, CRGB::Blue); // Just let us know we're running
      FastLED.show();
    }

    Serial.println("Getting METARs ...");
    if (getMetars()) {
      Serial.println("Refreshing LEDs.");
      FastLED.show();
      if ((DO_LIGHTNING && lightningLeds.size() > 0) || USE_LIGHT_SENSOR) {
        Serial.println("There is lightning or we're using a light sensor, so no long sleep.");
        digitalWrite(LED_BUILTIN, HIGH);
        delay(LOOP_INTERVAL); // pause during the interval
      } else {
        Serial.print("No lightning; Going into sleep for: ");
        Serial.println(REQUEST_INTERVAL);
        digitalWrite(LED_BUILTIN, HIGH);
        delay(REQUEST_INTERVAL);
      }
    } else {
      digitalWrite(LED_BUILTIN, HIGH);
      delay(RETRY_TIMEOUT); // try again if unsuccessful
    }
  } else {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(LOOP_INTERVAL); // pause during the interval
  }
}

bool getMetars(){
  lightningLeds.clear(); // clear out existing lightning LEDs since they're global
  fill_solid(leds, NUM_AIRPORTS, CRGB::Black); // Set everything to black just in case there is no report
  uint32_t t;
  char c;
  boolean readingAirport = false;
  boolean readingCondition = false;
  boolean readingWind = false;
  boolean readingGusts = false;
  boolean readingWxstring = false;

  std::vector<unsigned short int> led;
  String currentAirport = "";
  String currentCondition = "";
  String currentLine = "";
  String currentWind = "";
  String currentGusts = "";
  String currentWxstring = "";
  String airportString = "";
  bool firstAirport = true;
  for (int i = 0; i < NUM_AIRPORTS; i++) {
    if (airports[i] != "NULL" && airports[i] != "VFR" && airports[i] != "MVFR" && airports[i] != "WVFR" && airports[i] != "IFR" && airports[i] != "LIFR") {
      if (firstAirport) {
        firstAirport = false;
        airportString = airports[i];
      } else airportString = airportString + "," + airports[i];
    }
  }

  BearSSL::WiFiClientSecure client;
  client.setInsecure();
  Serial.println("\nStarting connection to server...");
  // if you get a connection, report back via serial:
  if (!client.connect(SERVER, 443)) {
    Serial.println("Connection failed!");
    client.stop();
    return false;
  } else {
    Serial.println("Connected ...");
    Serial.print("GET ");
    Serial.print(BASE_URI);
    Serial.print(airportString);
    Serial.println(" HTTP/1.1");
    Serial.print("Host: ");
    Serial.println(SERVER);
    Serial.println("User-Agent: LED Map Client");
    Serial.println("Connection: close");
    Serial.println();
    // Make a HTTP request, and print it to console:
    client.print("GET ");
    client.print(BASE_URI);
    client.print(airportString);
    client.println(" HTTP/1.1");
    client.print("Host: ");
    client.println(SERVER);
    client.println("User-Agent: LED Sectional Client");
    client.println("Connection: close");
    client.println();
    client.flush();
    t = millis(); // start time
    FastLED.clear();

    Serial.print("Getting data");

    while (!client.connected()) {
      if ((millis() - t) >= (READ_TIMEOUT * 1000)) {
        Serial.println("---Timeout---");
        client.stop();
        return false;
      }
      Serial.print(".");
      delay(1000);
    }

    Serial.println();

    while (client.connected()) {
      if ((c = client.read()) >= 0) {
        yield(); // Otherwise the WiFi stack can crash
        currentLine += c;
        if (c == '\n') currentLine = "";
        if (currentLine.endsWith("<station_id>")) { // start paying attention
          if (!led.empty()) { // we assume we are recording results at each change in airport
            for (vector<unsigned short int>::iterator it = led.begin(); it != led.end(); ++it) {
              doColor(currentAirport, *it, currentWind.toInt(), currentGusts.toInt(), currentCondition, currentWxstring);
            }
            led.clear();
          }
          currentAirport = ""; // Reset everything when the airport changes
          readingAirport = true;
          currentCondition = "";
          currentWind = "";
          currentGusts = "";
          currentWxstring = "";
        } else if (readingAirport) {
          if (!currentLine.endsWith("<")) {
            currentAirport += c;
          } else {
            readingAirport = false;
            for (unsigned short int i = 0; i < NUM_AIRPORTS; i++) {
              if (airports[i] == currentAirport) {
                led.push_back(i);
              }
            }
          }
        } else if (currentLine.endsWith("<wind_speed_kt>")) {
          readingWind = true;
        } else if (readingWind) {
          if (!currentLine.endsWith("<")) {
            currentWind += c;
          } else {
            readingWind = false;
          }
        } else if (currentLine.endsWith("<wind_gust_kt>")) {
          readingGusts = true;
        } else if (readingGusts) {
          if (!currentLine.endsWith("<")) {
            currentGusts += c;
          } else {
            readingGusts = false;
          }
        } else if (currentLine.endsWith("<flight_category>")) {
          readingCondition = true;
        } else if (readingCondition) {
          if (!currentLine.endsWith("<")) {
            currentCondition += c;
          } else {
            readingCondition = false;
          }
        } else if (currentLine.endsWith("<wx_string>")) {
          readingWxstring = true;
        } else if (readingWxstring) {
          if (!currentLine.endsWith("<")) {
            currentWxstring += c;
          } else {
            readingWxstring = false;
          }
        }
        t = millis(); // Reset timeout clock
      } else if ((millis() - t) >= (READ_TIMEOUT * 1000)) {
        Serial.println("---Timeout---");
        fill_solid(leds, NUM_AIRPORTS, CRGB::Cyan); // indicate status with LEDs
        FastLED.show();
        ledStatus = true;
        client.stop();
        return false;
      }
    }
  }
  // need to doColor this for the last airport
  for (vector<unsigned short int>::iterator it = led.begin(); it != led.end(); ++it) {
    doColor(currentAirport, *it, currentWind.toInt(), currentGusts.toInt(), currentCondition, currentWxstring);
  }
  led.clear();

  // Do the key LEDs now if they exist
  for (int i = 0; i < (NUM_AIRPORTS); i++) {
    // Use this opportunity to set colors for LEDs in our key then build the request string
    if (airports[i] == "VFR") leds[i] = CRGB::Green;
    else if (airports[i] == "WVFR") leds[i] = CRGB::Yellow;
    else if (airports[i] == "MVFR") leds[i] = CRGB::Blue;
    else if (airports[i] == "IFR") leds[i] = CRGB::Red;
    else if (airports[i] == "LIFR") leds[i] = CRGB::Magenta;
  }

  client.stop();
  return true;
}

void doColor(String identifier, unsigned short int led, int wind, int gusts, String condition, String wxstring) {
  CRGB color;
  Serial.print(identifier);
  Serial.print(": ");
  Serial.print(condition);
  Serial.print(" ");
  Serial.print(wind);
  Serial.print("G");
  Serial.print(gusts);
  Serial.print("kts LED ");
  Serial.print(led);
  Serial.print(" WX: ");
  Serial.println(wxstring);
  if (wxstring.indexOf("TS") != -1) {
    Serial.println("... found lightning!");
    lightningLeds.push_back(led);
  }
  if (condition == "LIFR" || identifier == "LIFR") color = CRGB::Magenta;
  else if (condition == "IFR") color = CRGB::Red;
  else if (condition == "MVFR") color = CRGB::Blue;
  else if (condition == "VFR") {
    if ((wind > WIND_THRESHOLD || gusts > WIND_THRESHOLD) && DO_WINDS) {
      color = CRGB::Yellow;
    } else {
      color = CRGB::Green;
    }
  } else color = CRGB::Black;

  leds[led] = color;
}
```

### Troubleshooting

If you hit any issues send me an email at seanwssmith@gmail.com