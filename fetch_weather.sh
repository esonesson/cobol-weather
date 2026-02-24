#!/bin/bash
# ============================================================
# fetch_weather.sh - API helper for COBOL Weather Application
# Handles HTTP requests and JSON parsing for the COBOL program
# Uses the free Open-Meteo API (no API key required)
# ============================================================

CITY_OUTPUT="/tmp/cobol_weather_cities.txt"
WEATHER_OUTPUT="/tmp/cobol_weather_data.txt"

GEOCODING_URL="https://geocoding-api.open-meteo.com/v1/search"
WEATHER_URL="https://api.open-meteo.com/v1/forecast"

# Maps WMO weather codes to descriptions and icons
get_weather_description() {
    local code=$1
    case $code in
        0)  echo "Clear sky|☀️" ;;
        1)  echo "Mainly clear|🌤️" ;;
        2)  echo "Partly cloudy|⛅" ;;
        3)  echo "Overcast|☁️" ;;
        45) echo "Foggy|🌫️" ;;
        48) echo "Depositing rime fog|🌫️" ;;
        51) echo "Light drizzle|🌦️" ;;
        53) echo "Moderate drizzle|🌦️" ;;
        55) echo "Dense drizzle|🌧️" ;;
        56) echo "Light freezing drizzle|🌧️" ;;
        57) echo "Dense freezing drizzle|🌧️" ;;
        61) echo "Slight rain|🌦️" ;;
        63) echo "Moderate rain|🌧️" ;;
        65) echo "Heavy rain|🌧️" ;;
        66) echo "Light freezing rain|🌧️" ;;
        67) echo "Heavy freezing rain|🌧️" ;;
        71) echo "Slight snow|🌨️" ;;
        73) echo "Moderate snow|🌨️" ;;
        75) echo "Heavy snow|❄️" ;;
        77) echo "Snow grains|❄️" ;;
        80) echo "Slight rain showers|🌦️" ;;
        81) echo "Moderate rain showers|🌧️" ;;
        82) echo "Violent rain showers|⛈️" ;;
        85) echo "Slight snow showers|🌨️" ;;
        86) echo "Heavy snow showers|❄️" ;;
        95) echo "Thunderstorm|⛈️" ;;
        96) echo "Thunderstorm with slight hail|⛈️" ;;
        99) echo "Thunderstorm with heavy hail|⛈️" ;;
        *)  echo "Unknown|❓" ;;
    esac
}

# Search for cities by name
search_cities() {
    local city_name="$1"
    local encoded_name
    encoded_name=$(printf '%s' "$city_name" | sed 's/ /%20/g')

    local response
    response=$(curl -s --max-time 10 \
        "${GEOCODING_URL}?name=${encoded_name}&count=5&language=en&format=json")

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        rm -f "$CITY_OUTPUT"
        echo "API_ERROR" > "$CITY_OUTPUT"
        return 1
    fi

    # Check if results exist
    local count
    count=$(echo "$response" | jq -r '.results | length // 0' 2>/dev/null)

    if [ "$count" = "0" ] || [ "$count" = "null" ]; then
        rm -f "$CITY_OUTPUT"
        return 0
    fi

    # Extract city data into pipe-delimited format
    echo "$response" | jq -r '.results[] |
        [.name // "Unknown",
         .country // "Unknown",
         .admin1 // "",
         (.latitude | tostring),
         (.longitude | tostring)] | join("|")' > "$CITY_OUTPUT"
}

# Fetch current weather for given coordinates
fetch_weather() {
    local lat="$1"
    local lon="$2"

    local response
    response=$(curl -s --max-time 10 \
        "${WEATHER_URL}?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&temperature_unit=celsius&wind_speed_unit=kmh")

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "API_ERROR" > "$WEATHER_OUTPUT"
        return 1
    fi

    local temp feels_like humidity wind_speed weather_code obs_time
    temp=$(echo "$response" | jq -r '.current.temperature_2m')
    feels_like=$(echo "$response" | jq -r '.current.apparent_temperature')
    humidity=$(echo "$response" | jq -r '.current.relative_humidity_2m')
    wind_speed=$(echo "$response" | jq -r '.current.wind_speed_10m')
    weather_code=$(echo "$response" | jq -r '.current.weather_code')
    obs_time=$(echo "$response" | jq -r '.current.time')

    local desc_icon
    desc_icon=$(get_weather_description "$weather_code")
    local description="${desc_icon%%|*}"
    local icon="${desc_icon##*|}"

    # Output pipe-delimited: temp|feels|humidity|wind|code|desc|icon|time
    echo "${temp}|${feels_like}|${humidity}|${wind_speed}|${weather_code}|${description}|${icon}|${obs_time}" > "$WEATHER_OUTPUT"
}

# Main dispatcher
case "$1" in
    search)
        search_cities "$2"
        ;;
    weather)
        fetch_weather "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {search|weather} [args...]"
        exit 1
        ;;
esac
