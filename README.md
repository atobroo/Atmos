<div align="center">

# ATMOS

**A living weather app for iOS, built with SwiftUI.**

The whole screen changes with the sky: warm gradients by day, a starry night after sunset, falling rain when it drizzles.

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0A84FF?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=flat&logo=apple&logoColor=white)
![Open-Meteo](https://img.shields.io/badge/data-Open--Meteo-2ea44f?style=flat)

</div>

<p align="center">
  <img src="screenshots/astana-night.jpg" width="24%" alt="Astana at night" />
  <img src="screenshots/tokyo-day.jpg" width="24%" alt="Tokyo, clear day" />
  <img src="screenshots/rain.jpg" width="24%" alt="Light drizzle with rain animation" />
  <img src="screenshots/cuiaba.jpg" width="24%" alt="Partly cloudy evening" />
</p>

## Features

- **Atmosphere that reacts to the weather.** Background, colors and particles change with conditions and time of day: sunny gradients, night sky with stars, animated rain, frost and lightning layers.
- **Next 24 hours.** Hourly capsules with temperature, icon and chance of precipitation.
- **Conditions at a glance.** Wind compass with a spinning turbine, humidity card with falling drops, feels-like, visibility and pressure with trend.
- **7-day forecast.** Smooth high/low temperature curves with daily icons.
- **Sun & Moon.** Sun path arc, sunrise and sunset, daylight length, moonrise, moonset and moon phase.
- **Your cities.** Save cities, search for new ones, or use your current location. Swipe between them.
- **Glass bottom bar and haptics** for a tactile, native feel.

<p align="center">
  <img src="screenshots/conditions.jpg" width="24%" alt="Conditions: wind, humidity, feels like, visibility, pressure" />
  <img src="screenshots/forecast-sun-moon.jpg" width="24%" alt="7-day forecast and Sun & Moon" />
  <img src="screenshots/dubai-night.jpg" width="24%" alt="Dubai, clear night" />
  <img src="screenshots/cities.jpg" width="24%" alt="My Cities list" />
</p>

<p align="center">
  <img src="screenshots/conditions-day.jpg" width="24%" alt="Conditions in daylight" />
  <img src="screenshots/forecast-day.jpg" width="24%" alt="Forecast and moon phase in daylight" />
</p>

## Tech stack

| | |
|---|---|
| UI | SwiftUI, custom animated layers, glass materials |
| Weather data | [Open-Meteo API](https://open-meteo.com) (free, no API key) |
| Location | CoreLocation, city search and geocoding |
| Astronomy | Custom sun and moon calculations |
| Feedback | Haptics |

## Project structure

```
WeatherService.swift      networking and weather models (Open-Meteo)
Untitled Project/
  ContentView 2.swift     main screen
  ForecastWave.swift      7-day forecast curves
  ConditionCards.swift    wind, humidity, feels like, visibility, pressure
  SunMoonSection.swift    sun path and moon phase
  MoonCalc.swift          moon phase calculations
  LightningLayer.swift    weather effects
  FrostLayer.swift
  GlassBottomBar.swift    bottom navigation
  CitiesListView.swift    saved cities
  CitySearchView.swift    city search
  LocationManager.swift   current location
  AtmosGeocoder.swift     city names from coordinates
  Haptics.swift
```

## Run it

1. Clone the repo:
   ```bash
   git clone https://github.com/atobroo/Atmos.git
   ```
2. Open `Atmos.xcodeproj` in Xcode.
3. Choose an iPhone simulator and press **Run** (⌘R).

No API keys or extra setup needed.

## Author

Made by **Aidos** · [@atobroo](https://github.com/atobroo)

Weather data by [Open-Meteo](https://open-meteo.com).
