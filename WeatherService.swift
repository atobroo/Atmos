import Foundation

// MARK: - API Response

struct WeatherResponse: Decodable {
    let current: CurrentWeather
    let hourly: HourlyWeather
    let daily: DailyWeather
    let utc_offset_seconds: Int?
}

// MARK: - Current Weather

struct CurrentWeather: Decodable {
    let time: String
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let wind_speed_10m: Double
    let wind_direction_10m: Double
    let weather_code: Int
    let is_day: Int
    let visibility: Double?
    let pressure_msl: Double?
}

// MARK: - Hourly Forecast

struct HourlyWeather: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int]
    let pressure_msl: [Double?]?
}

// MARK: - Daily Forecast

struct DailyWeather: Decodable {
    let time: [String]
    let sunrise: [String]
    let sunset: [String]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let weather_code: [Int]
}

// MARK: - Weather Service

struct WeatherService {

    func fetchWeather() async throws -> WeatherResponse {

        let urlString = """
        https://api.open-meteo.com/v1/forecast?latitude=51.1694&longitude=71.4491&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,weather_code,is_day&hourly=temperature_2m,weather_code,precipitation_probability&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min,weather_code&forecast_days=7&timezone=Asia%2FAlmaty
        """

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()

        return try decoder.decode(
            WeatherResponse.self,
            from: data
        )
    }
}
