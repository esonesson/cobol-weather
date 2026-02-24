# COBOL Weather

A terminal weather forecast application written in COBOL. Search for any city worldwide and get current weather conditions, powered by the free [Open-Meteo API](https://open-meteo.com/).

```
====================================================
    COBOL WEATHER FORECAST APPLICATION
    Powered by Open-Meteo API
====================================================

  Enter city name: Tokyo

  Cities found:
  ----------------------------------------------------
  1) Tokyo, Tokyo - Japan
  2) Tokyo, Central Province - Papua New Guinea
  3) Tokyo, Karnali Pradesh - Nepal
  ----------------------------------------------------
  Select a city (1-3): 1

  ====================================================
    ☁️  Weather for Tokyo, Japan
  ====================================================

    Condition:    Overcast
    Temperature:  7.5 C
    Feels like:   6.1 C
    Humidity:     96 %
    Wind speed:   4.0 km/h

    Observed at:  2026-02-24T19:45
  ====================================================
```

## Prerequisites

- **GnuCOBOL** - open-source COBOL compiler
- **curl** - for HTTP requests
- **jq** - for JSON parsing

### Install on macOS

```bash
brew install gnu-cobol jq
```

### Install on Debian/Ubuntu

```bash
sudo apt install gnucobol jq curl
```

## Build and Run

```bash
make run
```

Or build and run separately:

```bash
make build
./weather
```

Clean up build artifacts:

```bash
make clean
```

## How It Works

1. The user enters a city name
2. The **Open-Meteo Geocoding API** searches for matching cities (up to 5 results)
3. The user selects a city from the list
4. The **Open-Meteo Weather API** fetches current weather using the city's latitude/longitude
5. The COBOL program displays a formatted weather report
6. The user can search another city or exit

## Architecture

```
weather.cob          Main COBOL program - UI, user input, file I/O, display
fetch_weather.sh     Shell helper - HTTP requests (curl) and JSON parsing (jq)
Makefile             Build system
```

The COBOL program delegates HTTP and JSON handling to a shell helper script via `CALL "SYSTEM"`. Data is exchanged through temp files using pipe-delimited format, which COBOL parses with `UNSTRING`.

## APIs

Both APIs are free and require no API key:

- [Open-Meteo Geocoding API](https://open-meteo.com/en/docs/geocoding-api) - city search by name, returns coordinates
- [Open-Meteo Weather API](https://open-meteo.com/en/docs) - current weather by latitude/longitude

## Weather Conditions

The application maps WMO weather codes to human-readable descriptions with icons, covering clear skies, clouds, fog, rain, snow, and thunderstorms.
