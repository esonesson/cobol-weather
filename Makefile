COBC = cobc
COBFLAGS = -x -free
TARGET = weather
SOURCE = weather.cob

.PHONY: all build run clean

all: build

build: $(TARGET)

$(TARGET): $(SOURCE)
	$(COBC) $(COBFLAGS) -o $(TARGET) $(SOURCE)

run: build
	./$(TARGET)

clean:
	rm -f $(TARGET)
	rm -f /tmp/cobol_weather_cities.txt
	rm -f /tmp/cobol_weather_data.txt
