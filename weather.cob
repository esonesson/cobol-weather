       IDENTIFICATION DIVISION.
       PROGRAM-ID. WEATHER-APP.
       AUTHOR. COBOL-WEATHER.
      *> ============================================================
      *> COBOL Weather Application
      *> Fetches current weather for a user-chosen city using
      *> the free Open-Meteo API (no API key required).
      *> ============================================================

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CITY-FILE ASSIGN TO WS-CITY-FILEPATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
           SELECT WEATHER-FILE ASSIGN TO WS-WEATHER-FILEPATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD CITY-FILE.
       01 CITY-RECORD              PIC X(256).

       FD WEATHER-FILE.
       01 WEATHER-RECORD           PIC X(256).

       WORKING-STORAGE SECTION.
      *> File paths
       01 WS-CITY-FILEPATH         PIC X(256).
       01 WS-WEATHER-FILEPATH      PIC X(256).
       01 WS-FILE-STATUS           PIC XX.

      *> User input
       01 WS-CITY-INPUT            PIC X(100).
       01 WS-USER-CHOICE           PIC 9.
       01 WS-CONTINUE              PIC X.

      *> System command
       01 WS-COMMAND               PIC X(512).

      *> City search results (up to 5)
       01 WS-EOF-FLAG              PIC X VALUE "N".
       01 WS-CITY-COUNT            PIC 9 VALUE 0.
       01 WS-CITY-TABLE.
           05 WS-CITY-ENTRY OCCURS 5 TIMES.
               10 WS-CTY-NAME     PIC X(50).
               10 WS-CTY-COUNTRY  PIC X(50).
               10 WS-CTY-REGION   PIC X(50).
               10 WS-CTY-LAT      PIC X(12).
               10 WS-CTY-LON      PIC X(12).

      *> Weather data
       01 WS-WEATHER-DATA.
           05 WS-TEMPERATURE       PIC X(10).
           05 WS-FEELS-LIKE        PIC X(10).
           05 WS-HUMIDITY          PIC X(10).
           05 WS-WIND-SPEED        PIC X(10).
           05 WS-WEATHER-CODE      PIC X(5).
           05 WS-WEATHER-DESC      PIC X(40).
           05 WS-WEATHER-ICON      PIC X(10).
           05 WS-OBSERVATION-TIME  PIC X(20).

      *> Trimmed values for command building
       01 WS-TRIMMED-CITY          PIC X(100).
       01 WS-TRIMMED-LAT           PIC X(12).
       01 WS-TRIMMED-LON           PIC X(12).

      *> Display helpers
       01 WS-IDX                   PIC 9.
       01 WS-DISPLAY-LINE          PIC X(80).
       01 WS-SEPARATOR             PIC X(52).
       01 WS-HEADER-LINE           PIC X(52).

      *> Return code
       01 WS-RETURN-CODE           PIC 9(4).

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-PROGRAM
           PERFORM DISPLAY-BANNER
           PERFORM MAIN-LOOP
           PERFORM CLEANUP-PROGRAM
           STOP RUN.

      *> ============================================================
      *> Initialize file paths and variables
      *> ============================================================
       INITIALIZE-PROGRAM.
           MOVE "/tmp/cobol_weather_cities.txt"
               TO WS-CITY-FILEPATH
           MOVE "/tmp/cobol_weather_data.txt"
               TO WS-WEATHER-FILEPATH
           MOVE ALL "=" TO WS-SEPARATOR
           MOVE ALL "-" TO WS-HEADER-LINE
           CONTINUE.

      *> ============================================================
      *> Display the application banner
      *> ============================================================
       DISPLAY-BANNER.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY
               "    COBOL WEATHER FORECAST APPLICATION"
           DISPLAY
               "    Powered by Open-Meteo API"
           DISPLAY WS-SEPARATOR
           DISPLAY SPACES.

      *> ============================================================
      *> Main application loop
      *> ============================================================
       MAIN-LOOP.
           PERFORM UNTIL WS-CONTINUE = "N" OR "n"
               PERFORM GET-CITY-FROM-USER
               IF WS-CITY-INPUT NOT = SPACES
                   PERFORM SEARCH-CITIES
                   IF WS-CITY-COUNT > 0
                       PERFORM DISPLAY-CITY-OPTIONS
                       PERFORM GET-USER-SELECTION
                       IF WS-USER-CHOICE > 0 AND
                          WS-USER-CHOICE <= WS-CITY-COUNT
                           PERFORM FETCH-WEATHER
                           PERFORM DISPLAY-WEATHER
                       END-IF
                   ELSE
                       DISPLAY SPACES
                       DISPLAY "  No cities found. Try again."
                   END-IF
               END-IF

               DISPLAY SPACES
               DISPLAY
                  "  Search another city? (Y/N): "
                   WITH NO ADVANCING
               ACCEPT WS-CONTINUE
               DISPLAY SPACES
           END-PERFORM.

      *> ============================================================
      *> Get city name from user
      *> ============================================================
       GET-CITY-FROM-USER.
           DISPLAY "  Enter city name: " WITH NO ADVANCING
           ACCEPT WS-CITY-INPUT
           CONTINUE.

      *> ============================================================
      *> Search for cities using the geocoding API
      *> ============================================================
       SEARCH-CITIES.
           INITIALIZE WS-CITY-TABLE
           MOVE 0 TO WS-CITY-COUNT
           MOVE "N" TO WS-EOF-FLAG

           MOVE FUNCTION TRIM(WS-CITY-INPUT)
               TO WS-TRIMMED-CITY
           INITIALIZE WS-COMMAND
           STRING
               "./fetch_weather.sh search '"
                   DELIMITED SIZE
               WS-TRIMMED-CITY DELIMITED "  "
               "'" DELIMITED SIZE
               INTO WS-COMMAND
           END-STRING

           CALL "SYSTEM" USING
               FUNCTION TRIM(WS-COMMAND)

           OPEN INPUT CITY-FILE
           IF WS-FILE-STATUS NOT = "00"
               DISPLAY "  Error: Could not read city data."
               MOVE 0 TO WS-CITY-COUNT
           ELSE
               PERFORM UNTIL WS-CITY-COUNT >= 5
                   OR WS-EOF-FLAG = "Y"
                   READ CITY-FILE INTO CITY-RECORD
                       AT END
                           MOVE "Y" TO WS-EOF-FLAG
                       NOT AT END
                           ADD 1 TO WS-CITY-COUNT
                           PERFORM PARSE-CITY-LINE
                   END-READ
               END-PERFORM
               CLOSE CITY-FILE
           END-IF.


      *> ============================================================
      *> Parse a pipe-delimited city line
      *> Format: name|country|region|latitude|longitude
      *> ============================================================
       PARSE-CITY-LINE.
           UNSTRING CITY-RECORD DELIMITED BY "|"
               INTO WS-CTY-NAME(WS-CITY-COUNT)
                    WS-CTY-COUNTRY(WS-CITY-COUNT)
                    WS-CTY-REGION(WS-CITY-COUNT)
                    WS-CTY-LAT(WS-CITY-COUNT)
                    WS-CTY-LON(WS-CITY-COUNT)
           END-UNSTRING.

      *> ============================================================
      *> Display city options for user selection
      *> ============================================================
       DISPLAY-CITY-OPTIONS.
           DISPLAY SPACES
           DISPLAY "  Cities found:"
           DISPLAY "  " WS-HEADER-LINE

           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CITY-COUNT

               DISPLAY "  " WS-IDX ") "
                   FUNCTION TRIM(WS-CTY-NAME(WS-IDX))
                   ", "
                   FUNCTION TRIM(WS-CTY-REGION(WS-IDX))
                   " - "
                   FUNCTION TRIM(WS-CTY-COUNTRY(WS-IDX))
           END-PERFORM

           DISPLAY "  " WS-HEADER-LINE.

      *> ============================================================
      *> Get user selection
      *> ============================================================
       GET-USER-SELECTION.
           DISPLAY "  Select a city (1-"
               WS-CITY-COUNT "): "
               WITH NO ADVANCING
           ACCEPT WS-USER-CHOICE

           IF WS-USER-CHOICE < 1 OR
              WS-USER-CHOICE > WS-CITY-COUNT
               DISPLAY "  Invalid selection."
               MOVE 0 TO WS-USER-CHOICE
           END-IF.

      *> ============================================================
      *> Fetch weather for selected city
      *> ============================================================
       FETCH-WEATHER.
           INITIALIZE WS-WEATHER-DATA

           MOVE FUNCTION TRIM(WS-CTY-LAT(WS-USER-CHOICE))
               TO WS-TRIMMED-LAT
           MOVE FUNCTION TRIM(WS-CTY-LON(WS-USER-CHOICE))
               TO WS-TRIMMED-LON
           INITIALIZE WS-COMMAND
           STRING
               "./fetch_weather.sh weather '"
                   DELIMITED SIZE
               WS-TRIMMED-LAT DELIMITED "  "
               "' '" DELIMITED SIZE
               WS-TRIMMED-LON DELIMITED "  "
               "'" DELIMITED SIZE
               INTO WS-COMMAND
           END-STRING

           CALL "SYSTEM" USING
               FUNCTION TRIM(WS-COMMAND)

           OPEN INPUT WEATHER-FILE
           IF WS-FILE-STATUS NOT = "00"
               DISPLAY "  Error: Could not read weather data."
           ELSE
               READ WEATHER-FILE INTO WEATHER-RECORD
                   AT END
                       DISPLAY "  Error: Empty weather data."
                   NOT AT END
                       PERFORM PARSE-WEATHER-LINE
               END-READ
               CLOSE WEATHER-FILE
           END-IF.

      *> ============================================================
      *> Parse pipe-delimited weather line
      *> Format: temp|feels|humidity|wind|code|desc|icon|time
      *> ============================================================
       PARSE-WEATHER-LINE.
           UNSTRING WEATHER-RECORD DELIMITED BY "|"
               INTO WS-TEMPERATURE
                    WS-FEELS-LIKE
                    WS-HUMIDITY
                    WS-WIND-SPEED
                    WS-WEATHER-CODE
                    WS-WEATHER-DESC
                    WS-WEATHER-ICON
                    WS-OBSERVATION-TIME
           END-UNSTRING.

      *> ============================================================
      *> Display the weather report
      *> ============================================================
       DISPLAY-WEATHER.
           DISPLAY SPACES
           DISPLAY "  " WS-SEPARATOR
           DISPLAY "    "
               FUNCTION TRIM(WS-WEATHER-ICON) "  Weather for "
               FUNCTION TRIM(WS-CTY-NAME(WS-USER-CHOICE))
               ", "
               FUNCTION TRIM(WS-CTY-COUNTRY(WS-USER-CHOICE))
           DISPLAY "  " WS-SEPARATOR
           DISPLAY SPACES

           DISPLAY "    Condition:    "
               FUNCTION TRIM(WS-WEATHER-DESC)
           DISPLAY "    Temperature:  "
               FUNCTION TRIM(WS-TEMPERATURE) " C"
           DISPLAY "    Feels like:   "
               FUNCTION TRIM(WS-FEELS-LIKE) " C"
           DISPLAY "    Humidity:     "
               FUNCTION TRIM(WS-HUMIDITY) " %"
           DISPLAY "    Wind speed:   "
               FUNCTION TRIM(WS-WIND-SPEED) " km/h"
           DISPLAY SPACES
           DISPLAY "    Observed at:  "
               FUNCTION TRIM(WS-OBSERVATION-TIME)

           DISPLAY "  " WS-SEPARATOR.

      *> ============================================================
      *> Cleanup temp files
      *> ============================================================
       CLEANUP-PROGRAM.
           DISPLAY "  Thank you for using COBOL Weather!"
           DISPLAY WS-SEPARATOR
           CALL "SYSTEM" USING
               "rm -f /tmp/cobol_weather_cities.txt "
             & "/tmp/cobol_weather_data.txt"
           CONTINUE.
