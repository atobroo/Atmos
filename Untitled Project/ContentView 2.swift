//
//  ContentView.swift
//  Atmos
//

import SwiftUI
import Foundation
import Combine
import UIKit


// MARK: - Design tokens

enum AtmosPalette {
    static let deepNavy = Color(red: 0.016, green: 0.027, blue: 0.075)
    static let midnight = Color(red: 0.035, green: 0.070, blue: 0.170)
    static let indigo = Color(red: 0.075, green: 0.060, blue: 0.200)
    static let cyan = Color(red: 0.38, green: 0.86, blue: 0.97)
    static let violet = Color(red: 0.62, green: 0.54, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.40)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)
}

// MARK: - Small helpers

private func fract(_ value: Double) -> Double {
    value - floor(value)
}

enum SkyCondition {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunderstorm

    init(code: Int) {
        switch code {
        case 0, 1: self = .clear
        case 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: self = .rain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Rime fog"
        case 51: return "Light drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71: return "Light snow"
        case 73: return "Snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80: return "Light showers"
        case 81: return "Rain showers"
        case 82: return "Violent showers"
        case 85: return "Snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unrecognised conditions"
        }
    }

    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    func glow(isDay: Bool) -> Color {
        switch self {
        case .clear: return isDay ? AtmosPalette.amber : AtmosPalette.violet
        case .partlyCloudy: return isDay ? AtmosPalette.amber : AtmosPalette.violet
        case .thunderstorm: return AtmosPalette.violet
        case .snow: return Color(red: 0.75, green: 0.88, blue: 1.0)
        default: return AtmosPalette.cyan
        }
    }

    var hasHaze: Bool {
        switch self {
        case .clear: return false
        default: return true
        }
    }
}

enum AtmosFormat {
    static func degrees(_ value: Double) -> String { "\(Int(value.rounded()))°" }
    static func clock(_ iso: String) -> String {
        guard let part = iso.split(separator: "T").last else { return iso }
        return String(part.prefix(5))
    }
    static func minutes(_ iso: String) -> Int? {
        let parts = clock(iso).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
    static func weekday(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(dateString.prefix(10))) else { return dateString }
        let output = DateFormatter()
        output.locale = Locale.current
        output.timeZone = TimeZone(secondsFromGMT: 0)
        output.dateFormat = "EEE"
        return output.string(from: date)
    }
    static func compass(_ degrees: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized / 22.5).rounded()) % 16]
    }
    static func isDaytime(at time: String, daily: DailyWeather) -> Bool {
        let date = String(time.prefix(10))
        guard let i = daily.time.firstIndex(where: { $0.hasPrefix(date) }),
              i < daily.sunrise.count, i < daily.sunset.count,
              let now = minutes(time),
              let rise = minutes(daily.sunrise[i]),
              let sunsetMinutes = minutes(daily.sunset[i]) else { return true }
        return now >= rise && now < sunsetMinutes
    }
}

// MARK: - Data loading

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "metric"
    case imperial = "imperial"
    var id: String { rawValue }
    var name: String { self == .metric ? "Metric (°C, km/h)" : "Imperial (°F, mph)" }
    var temperatureUnit: String { self == .metric ? "celsius" : "fahrenheit" }
    var windUnit: String { self == .metric ? "kmh" : "mph" }
    var windSymbol: String { self == .metric ? "km/h" : "mph" }
}

enum AtmosWeatherLoader {
    static func fetch(for city: SavedCity, units: UnitSystem) async throws -> WeatherResponse {
        try await fetch(latitude: city.latitude, longitude: city.longitude, units: units)
    }
    static func fetch(latitude: Double, longitude: Double, units: UnitSystem) async throws -> WeatherResponse {
        let address = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,weather_code,is_day,visibility,pressure_msl"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,pressure_msl"
            + "&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min,weather_code"
            + "&timezone=auto&forecast_days=7"
            + "&temperature_unit=\(units.temperatureUnit)"
            + "&wind_speed_unit=\(units.windUnit)"
        guard let url = URL(string: address) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }
}

@MainActor
final class AtmosViewModel: ObservableObject {
    enum State { case loading; case loaded(WeatherResponse); case failed(String) }

    init() {
        let savedUnit = UserDefaults.standard.string(forKey: "atmos.unitSystem") ?? UnitSystem.metric.rawValue
        self.unitSystem = UnitSystem(rawValue: savedUnit) ?? .metric
        loadCities()
    }

    @Published private(set) var cities: [SavedCity] = []
    @Published var selectedIndex: Int = 0
    var selectedCity: SavedCity? {
        guard cities.indices.contains(selectedIndex) else { return nil }
        return cities[selectedIndex]
    }

    @Published private(set) var states: [UUID: State] = [:]
    func state(for city: SavedCity) -> State { states[city.id] ?? .loading }

    @Published var refreshMessage: String?
    @Published var fetchedAt = Date()
    @Published var unitSystem: UnitSystem = .metric {
        didSet {
            UserDefaults.standard.set(unitSystem.rawValue, forKey: "atmos.unitSystem")
            refreshMessage = nil
            Task { await loadSelected() }
        }
    }

    private let storageKey = "atmos.savedCities"
    private let indexKey = "atmos.selectedIndex"

    private func loadCities() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SavedCity].self, from: data),
           !decoded.isEmpty {
            cities = decoded
        } else {
            cities = [.astana]
        }
        let stored = UserDefaults.standard.integer(forKey: indexKey)
        selectedIndex = min(max(stored, 0), cities.count - 1)
    }

    private func persistCities() {
        if let data = try? JSONEncoder().encode(cities) { UserDefaults.standard.set(data, forKey: storageKey) }
        UserDefaults.standard.set(selectedIndex, forKey: indexKey)
    }

    func addCity(_ city: SavedCity) {
        if let existing = cities.firstIndex(where: { $0.name == city.name && $0.country == city.country }) {
            selectedIndex = existing; persistCities(); return
        }
        cities.append(city)
        selectedIndex = cities.count - 1
        persistCities()
        Task { await load(city: city) }
    }

    func removeCity(at index: Int) {
        guard cities.indices.contains(index), cities.count > 1 else { return }
        let removed = cities.remove(at: index)
        states[removed.id] = nil
        selectedIndex = min(selectedIndex, cities.count - 1)
        persistCities()
    }

    func removeCity(_ city: SavedCity) {
        guard let index = cities.firstIndex(of: city) else { return }
        removeCity(at: index)
    }

    func moveCity(from source: IndexSet, to destination: Int) {
        cities.move(fromOffsets: source, toOffset: destination)
        persistCities()
    }

    func loadSelected() async {
        guard let city = selectedCity else { return }
        await load(city: city)
    }

    func load(city: SavedCity) async {
        print("Atmos: loading \(city.name)")
        if states[city.id] == nil { states[city.id] = .loading }
        do {
            let result = try await AtmosWeatherLoader.fetch(for: city, units: unitSystem)
            print("Atmos: loaded \(city.name)")
            states[city.id] = .loaded(result)
            if city.id == selectedCity?.id { fetchedAt = Date(); refreshMessage = nil }
        } catch {
            print("Atmos: failed \(city.name): \(error)")
            if (error as? URLError)?.code == .cancelled { return }
            let message = Self.friendlyMessage(for: error)
            let hadData: Bool = {
                if case .loaded = states[city.id] { return true }
                return false
            }()
            if hadData {
                if city.id == selectedCity?.id { refreshMessage = message }
            } else {
                states[city.id] = .failed(message)
            }
        }
    }

    func loadIfNeeded(city: SavedCity) async {
        if case .loaded = state(for: city) { return }
        await load(city: city)
    }

    private static func friendlyMessage(for error: Error) -> String {
        if error is URLError { return "Atmos couldn't reach the weather service. Check your connection and try again." }
        if error is DecodingError { return "The weather data arrived in a shape Atmos couldn't read." }
        return "Something went wrong while loading the weather."
    }
}

// MARK: - Root view
struct AtmosMainView: View {
    @StateObject private var model = AtmosViewModel()
    @State private var isSearching = false
    @State private var isShowingList = false
    @State private var isShowingSettings = false
    
    var body: some View {
        ZStack {
            // 1. Фон (градиент и звезды)
            AtmosBackground(
                glow: backgroundGlow,
                showStars: showStars,
                condition: currentCondition,
                isDay: currentIsDay,
                                temperatureC: currentTemperatureC
            )
            
            // 2. АНИМАЦИЯ НА ВЕСЬ ЭКРАН (дождь, снег, молния)
            if let condition = currentCondition {
                PrecipitationBackdrop(condition: condition)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // 3. Основной контент (погода)
            if model.cities.isEmpty {
                LoadingView()
            } else {
                citiesPager
            }
            // 4. Мороз: иней по краям экрана
                    if frostLevel > 0 {
                        FrostLayer(level: frostLevel)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
          }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSearching) {
            CitySearchView { city in
                model.addCity(city)
            }
        }
        .sheet(isPresented: $isShowingList) {
            CitiesListView(model: model)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(model: model)
        }
        .task { await model.loadSelected() }
    }
    
    @ViewBuilder
    private var citiesPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(model.cities.enumerated()), id: \.element.id) { index, city in
                        CityPageView(
                            model: model,
                            city: city,
                            onSearch: { isSearching = true },
                            onShowList: { isShowingList = true },
                            onShowSettings: { isShowingSettings = true }
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding<Int?>(
                get: { model.selectedIndex },
                set: { newIndex in
                    if let newIndex = newIndex, newIndex != model.selectedIndex {
                        model.selectedIndex = newIndex
                        Haptics.selection()
                        Task { await model.loadSelected() }
                    }
                }
            ))
            .safeAreaInset(edge: .bottom) {
                GlassBottomBar(
                    count: model.cities.count,
                    selected: model.selectedIndex,
                    onSelect: { index in
                        withAnimation(.snappy) { model.selectedIndex = index }
                        Haptics.selection()
                        Task { await model.loadSelected() }
                    },
                    onLeft: { isShowingSettings = true },
                    onRight: { isShowingList = true }
                )
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
        }
        .ignoresSafeArea()
    }
    
    // 0 при -5° и теплее, 1 при -35° и холоднее
    private var frostLevel: Double {
        guard let t = currentTemperatureC else { return 0 }
        return 0
    }
    
    private var backgroundGlow: Color {
        guard let city = model.selectedCity, let current = loadedWeather(for: city)?.current else { return AtmosPalette.cyan }
        return SkyCondition(code: current.weather_code).glow(isDay: current.is_day == 1)
    }
    
    private var showStars: Bool {
        guard let city = model.selectedCity, let current = loadedWeather(for: city)?.current else { return true }
        return current.is_day == 0
    }
    
    private var currentCondition: SkyCondition? {
        guard let city = model.selectedCity, let weather = loadedWeather(for: city) else { return nil }
        return SkyCondition(code: weather.current.weather_code)
    }
    
    private var currentTemperatureC: Double? {
        guard let city = model.selectedCity, let weather = loadedWeather(for: city) else { return nil }
        let value: Double = weather.current.temperature_2m
        return model.unitSystem == .imperial ? (value - 32) / 1.8 : value
    }
    private var currentIsDay: Bool { 
        guard let city = model.selectedCity, let weather = loadedWeather(for: city) else { return false }
        return weather.current.is_day == 1
    }
    
    private func loadedWeather(for city: SavedCity) -> WeatherResponse? {
        if case .loaded(let weather) = model.state(for: city) { return weather }
        return nil
    }
}
// MARK: - WeatherScreen
struct CityPageView: View {
    @ObservedObject var model: AtmosViewModel
    let city: SavedCity
    let onSearch: () -> Void
    let onShowList: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        switch model.state(for: city) {
        case .loading:
            LoadingView()

        case .failed(let message):
            ErrorView(message: message) {
                Task { await model.load(city: city) }
            }

        case .loaded(let weather):
            WeatherScreen(
                weather: weather,
                refreshMessage: model.refreshMessage,
                fetchedAt: model.fetchedAt,
                city: city,
                canDelete: model.cities.count > 1,
                unitSymbol: model.unitSystem.windSymbol,
                onRefresh: { await model.load(city: city) },
                onSearch: onSearch,
                onShowList: onShowList,
                onShowSettings: onShowSettings,
                onDismissMessage: { model.refreshMessage = nil },
                onDelete: { model.removeCity(city) }
            )
        }
    }
}
struct WeatherScreen: View {
    let weather: WeatherResponse
    let refreshMessage: String?
    let fetchedAt: Date
    let city: SavedCity
    let canDelete: Bool
    let unitSymbol: String
    let onRefresh: () async -> Void
    let onSearch: () -> Void
    let onShowList: () -> Void
    let onShowSettings: () -> Void
    let onDismissMessage: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        // Берем ширину экрана напрямую, без GeometryReader
        let contentWidth = UIScreen.main.bounds.width - 40
        
        ScrollView(showsIndicators: false) {
            Color.clear.frame(height: 100) // <-- ДОБАВЬ ЭТО
            VStack(spacing: 34) {
                HeaderView(city: city, onRefresh: { Task { await onRefresh() } }, onSearch: onSearch, onShowList: onShowList, onShowSettings: onShowSettings, onDelete: onDelete, canDelete: canDelete)
                
                if let refreshMessage = refreshMessage {
                    Text(refreshMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AtmosPalette.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
                        .onTapGesture { onDismissMessage() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                HeroSection(weather: weather, width: contentWidth)
                HourlyStrip(weather: weather)
                ConditionsSection(current: weather.current, hourly: weather.hourly, unitSymbol: unitSymbol)
                ForecastWave(daily: weather.daily)
                SunMoonSection(current: weather.current, daily: weather.daily, fetchedAt: fetchedAt, city: city, utcOffset: weather.utc_offset_seconds)
                FooterView(updated: weather.current.time)
                
                // Запас внизу, чтобы карточки уезжали выше точек
                Color.clear.frame(height: 80)
            }
            .frame(width: contentWidth)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .refreshable { await onRefresh() }
    }
}
// MARK: - Header
struct HeaderView: View {
    let city: SavedCity
    let onRefresh: () -> Void
    let onSearch: () -> Void
    let onShowList: () -> Void
    let onShowSettings: () -> Void
    let onDelete: (() -> Void)?
    let canDelete: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ATMOS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .kerning(5)
                    .foregroundStyle(AtmosPalette.cyan)

                HStack(spacing: 10) {
                    Button(action: { Haptics.impact(); onSearch() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AtmosPalette.cyan)
                            Text(city.name)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if canDelete, let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label("Remove \(city.name)", systemImage: "trash")
                            }
                        }
                    }

                    Button(action: { Haptics.impact(); onSearch() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .modifier(HeaderGlass())
                            .offset(y: 2)
                    }
                    .buttonStyle(.plain)
                }

                Text(city.country)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
            }
            Spacer()
        }
    }
}

private struct HeaderGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
    }
}

// MARK: - Hero
struct HeroSection: View {
    let weather: WeatherResponse
    let width: CGFloat

    var body: some View {
        let current = weather.current
        let isDay = current.is_day == 1
        // Включена нормальная погода. Если захочешь снова протестировать грозу, просто поменяй на SkyCondition(code: 95)
        let condition = SkyCondition(code: current.weather_code)
        let orbSize = width * 0.66
        let tempSize = min(width * 0.44, 170)

        ZStack(alignment: .topTrailing) {
            WeatherOrb(condition: condition, isDay: isDay).frame(width: orbSize, height: orbSize).offset(x: orbSize * 0.22, y: -orbSize * 0.05)
            VStack(alignment: .leading, spacing: 10) {
                Text(AtmosFormat.degrees(current.temperature_2m))
                    .font(.system(size: tempSize, weight: .thin, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color.white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(SkyCondition.description(for: current.weather_code)).font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("Feels like \(AtmosFormat.degrees(current.apparent_temperature))").font(.system(size: 15, weight: .medium)).foregroundStyle(AtmosPalette.secondaryText)
                if let high = weather.daily.temperature_2m_max.first, let low = weather.daily.temperature_2m_min.first {
                    HStack(spacing: 14) {
                        Label(AtmosFormat.degrees(high), systemImage: "arrow.up")
                        Label(AtmosFormat.degrees(low), systemImage: "arrow.down")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(AtmosPalette.cyan).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: width * 0.78, alignment: .topLeading)
        
    }
}

struct WeatherOrb: View {
    let condition: SkyCondition
    let isDay: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var float = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let glow = condition.glow(isDay: isDay)
            ZStack {
                Circle().fill(RadialGradient(colors: [glow.opacity(0.55), glow.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2)).blur(radius: 18)
                ForEach(0..<3, id: \.self) { index in
                    Circle().strokeBorder(AngularGradient(colors: [glow.opacity(0), glow.opacity(0.65), glow.opacity(0)], center: .center), lineWidth: 1)
                        .scaleEffect(0.5 + 0.18 * CGFloat(index))
                        .rotationEffect(.degrees(spin ? (index % 2 == 0 ? 360 : -360) : 0))
                        .animation(reduceMotion ? nil : .linear(duration: 36 + Double(index) * 12).repeatForever(autoreverses: false), value: spin)
                }
                if condition.hasHaze {
                    Ellipse().fill(Color.white.opacity(0.10)).frame(width: size * 0.62, height: size * 0.26).blur(radius: 14)
                        .offset(x: float ? -size * 0.06 : size * 0.06, y: size * 0.14)
                    Ellipse().fill(glow.opacity(0.16)).frame(width: size * 0.5, height: size * 0.2).blur(radius: 12)
                        .offset(x: float ? size * 0.07 : -size * 0.05, y: -size * 0.12)
                }
                if condition == .clear {
                    Circle().fill(RadialGradient(colors: [Color.white.opacity(0.9), glow.opacity(0.35), glow.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.2))
                        .frame(width: size * 0.4, height: size * 0.4)
                }
                Image(systemName: condition.symbol(isDay: isDay)).symbolRenderingMode(.multicolor).font(.system(size: size * 0.30, weight: .regular))
                    .shadow(color: glow.opacity(0.55), radius: 22).offset(y: float ? -6 : 6)
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            guard !reduceMotion else { return }
            spin = true
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { float = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Rain and Snow
struct PrecipitationBackdrop: View {
    let condition: SkyCondition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !reduceMotion {
                switch condition {
                case .rain, .drizzle: PrecipitationLayer(kind: .rain)
                case .snow: PrecipitationLayer(kind: .snow)
                case .thunderstorm: PrecipitationLayer(kind: .thunderstorm)
                default: Color.clear
                }
            } else { Color.clear }
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PrecipitationLayer: View {
    enum Kind { case rain, snow, thunderstorm }
    let kind: Kind

    var body: some View {
        ZStack {
            if kind == .rain || kind == .thunderstorm {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let count = 45
                        for i in 0..<count {
                            let seed = Double(i) + 1
                            let x = CGFloat(fract(sin(seed * 12.9898) * 43758.5453)) * size.width
                            let offset = fract(sin(seed * 78.233) * 12345.6789)
                            let speed = 0.7 + offset * 0.5
                            let progress = fract(offset + t * speed)
                            let y = CGFloat(progress) * (size.height + 30) - 15
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x - 4, y: y + 16))
                            context.stroke(path, with: .color(.white.opacity(0.18 + offset * 0.2)), lineWidth: 1)
                        }
                    }
                }
            }

            if kind == .snow {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let count = 30
                        for i in 0..<count {
                            let seed = Double(i) + 1
                            let x = CGFloat(fract(sin(seed * 12.9898) * 43758.5453)) * size.width
                            let offset = fract(sin(seed * 78.233) * 12345.6789)
                            let speed = 0.10 + offset * 0.08
                            let progress = fract(offset + t * speed)
                            let y = CGFloat(progress) * (size.height + 20) - 10
                            let sway = CGFloat(sin(t + seed)) * 8
                            let radius = CGFloat(1.5 + offset * 2)
                            let rect = CGRect(x: x + sway, y: y, width: radius, height: radius)
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                        }
                    }
                }
            }

            if kind == .thunderstorm {
                LightningLayer()
            }
        }
    }
}


// MARK: - Hourly forecast
struct HourSlot: Identifiable {
    let id: String; let label: String; let symbol: String; let temperature: String; let precipitation: Int; let isNow: Bool
}

struct HourlyStrip: View {
    let weather: WeatherResponse

    private var slots: [HourSlot] {
        let hourly = weather.hourly
        let available = min(hourly.time.count, hourly.temperature_2m.count, hourly.weather_code.count, hourly.precipitation_probability.count)
        guard available > 0 else { return [] }
        let currentHour = String(weather.current.time.prefix(13))
        let start = hourly.time.prefix(available).firstIndex(where: { String($0.prefix(13)) >= currentHour }) ?? 0
        let end = min(start + 24, available)
        return (start..<end).map { index in
            let time = hourly.time[index]
            let isDay = AtmosFormat.isDaytime(at: time, daily: weather.daily)
            let condition = SkyCondition(code: hourly.weather_code[index])
            return HourSlot(id: time, label: index == start ? "Now" : AtmosFormat.clock(time), symbol: condition.symbol(isDay: isDay), temperature: AtmosFormat.degrees(hourly.temperature_2m[index]), precipitation: hourly.precipitation_probability[index], isNow: index == start)
        }
    }

    var body: some View {
        let items = slots
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "NEXT 24 HOURS", icon: "clock")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) { ForEach(items) { slot in HourCell(slot: slot) } }.padding(.horizontal, 1)
                }
            }
        }
    }
}

struct HourCell: View {
    let slot: HourSlot
    var body: some View {
        VStack(spacing: 12) {
            Text(slot.label).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(slot.isNow ? AtmosPalette.cyan : AtmosPalette.secondaryText)
            Image(systemName: slot.symbol).symbolRenderingMode(.multicolor).font(.system(size: 24)).frame(height: 28)
            Text(slot.temperature).font(.system(size: 20, weight: .medium, design: .rounded))
            HStack(spacing: 3) {
                Image(systemName: "drop.fill").font(.system(size: 8))
                Text("\(slot.precipitation)%").font(.system(size: 11, weight: .semibold, design: .rounded))
            }.foregroundStyle(slot.precipitation > 0 ? AtmosPalette.cyan : AtmosPalette.tertiaryText)
        }
        .padding(.vertical, 14).frame(width: 66)
        .background(Capsule(style: .continuous).fill(LinearGradient(colors: slot.isNow ? [AtmosPalette.cyan.opacity(0.28), AtmosPalette.violet.opacity(0.12)] : [Color.white.opacity(0.07), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(slot.isNow ? 0.35 : 0.08), lineWidth: 1))
    }
}

// MARK: - Metrics
struct MetricsRow: View {
    let current: CurrentWeather
    let unitSymbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "CONDITIONS", icon: "gauge.with.dots.needle.33percent")
            
            HStack(alignment: .top, spacing: 14) { // <-- Добавили alignment: .top
                WindPanel(speed: current.wind_speed_10m, direction: current.wind_direction_10m, unitSymbol: unitSymbol)
                    .frame(maxHeight: .infinity) // <-- Растягиваем на всю доступную высоту
                
                HumidityPanel(humidity: current.relative_humidity_2m)
                    .frame(maxHeight: .infinity) // <-- Растягиваем на всю доступную высоту
            }
            .fixedSize(horizontal: false, vertical: true) // <-- Заставляем их быть одинаковыми
        }
    }
}

struct WindPanel: View {
    let speed: Double
    let direction: Double
    let unitSymbol: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownDirection: Double = 0

    // Шкала Бофорта считается в км/ч, поэтому мили в час переводим
    private var speedKmh: Double {
        unitSymbol == "mph" ? speed * 1.609344 : speed
    }

    // 0...12 по шкале Бофорта (верхние границы в км/ч)
    private var beaufort: Int {
        let limits: [Double] = [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118]
        for (index, limit) in limits.enumerated() {
            if speedKmh < limit { return index }
        }
        return 12
    }

    private var levelText: String {
        let names: [String] = [
            "Calm", "Light air", "Light breeze", "Gentle breeze", "Moderate breeze",
            "Fresh breeze", "Strong breeze", "Near gale", "Gale", "Strong gale",
            "Storm", "Violent storm", "Hurricane"
        ]
        return names[beaufort]
    }

    private var levelColor: Color {
        if beaufort <= 3 { return AtmosPalette.cyan }
        if beaufort <= 5 { return AtmosPalette.amber }
        return Color(red: 1.0, green: 0.42, blue: 0.35)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WIND")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .kerning(2)
                .foregroundStyle(AtmosPalette.secondaryText)

            WindCompassView(
                direction: shownDirection,
                speedKmh: speedKmh,
                levelColor: levelColor,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(speed.rounded()))")
                    .font(.system(size: 36, weight: .light, design: .rounded))
                Text(unitSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
            }

            Text(levelText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(levelColor)

            beaufortBar

            Text("From \(AtmosFormat.compass(direction))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AtmosPalette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                shownDirection = direction
            }
        }
        .onChange(of: direction) { _, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                shownDirection = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wind \(Int(speed.rounded())) \(unitSymbol), \(levelText), from \(AtmosFormat.compass(direction))")
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.05))
            WindStreaksView(
                direction: direction,
                speedKmh: speedKmh,
                beaufort: beaufort,
                color: levelColor,
                reduceMotion: reduceMotion
            )
        }
    }

    // 12 делений: горит столько, какой сейчас уровень по Бофорту
    private var beaufortBar: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index < beaufort ? levelColor : Color.white.opacity(0.15))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Компас с ветряком
struct WindCompassView: View {
    let direction: Double      // откуда дует ветер, в градусах
    let speedKmh: Double
    let levelColor: Color
    let reduceMotion: Bool

    private let radius: CGFloat = 60
    private let arcWidth: Double = 32

    private var rotationsPerSecond: Double {
        min(max(speedKmh, 0), 60) / 60 * 0.8
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(levelColor.opacity(0.06))
                .frame(width: 136, height: 136)

            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)

            ticks
            letters
            directionArc
            directionDot
            rotor

            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
        }
        .frame(width: 120, height: 120)
    }

    // Деления через каждые 10°, крупные на сторонах света
    private var ticks: some View {
        ForEach(0..<36, id: \.self) { index in
            let isMajor: Bool = index % 9 == 0
            let tickHeight: CGFloat = isMajor ? 9 : 4
            Capsule()
                .fill(Color.white.opacity(isMajor ? 0.5 : 0.22))
                .frame(width: isMajor ? 1.5 : 1, height: tickHeight)
                .offset(y: -(radius - tickHeight / 2 - 1))
                .rotationEffect(.degrees(Double(index) * 10))
        }
    }

    private var letters: some View {
        ZStack {
            Text("N").foregroundStyle(AtmosPalette.cyan).offset(y: -40)
            Text("E").foregroundStyle(Color.white.opacity(0.45)).offset(x: 40)
            Text("S").foregroundStyle(Color.white.opacity(0.45)).offset(y: 40)
            Text("W").foregroundStyle(Color.white.opacity(0.45)).offset(x: -40)
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
    }

    // Светящаяся дуга на ободе. trim начинается на «3 часах», поэтому вычитаем 90°
    private var directionArc: some View {
        let fraction: CGFloat = CGFloat(arcWidth / 360)
        let turn: Double = direction - 90 - arcWidth / 2
        return ZStack {
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(levelColor.opacity(0.25), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(turn))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(levelColor.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(turn))
        }
    }

    private var directionDot: some View {
        Circle()
            .fill(levelColor)
            .frame(width: 9, height: 9)
            .offset(y: -radius)
            .rotationEffect(.degrees(direction))
    }

    @ViewBuilder
    private var rotor: some View {
        let isPaused: Bool = speedKmh < 1 || reduceMotion
        let isFast: Bool = speedKmh >= 25
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { timeline in
            let seconds: Double = timeline.date.timeIntervalSinceReferenceDate
            let spun: Double = (seconds * rotationsPerSecond * 360).truncatingRemainder(dividingBy: 360)
            let angle: Double = isPaused ? 20 : spun
            ZStack {
                if isFast {
                    // Размытый диск, как у быстро вращающегося винта
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 64, height: 64)
                }
                FanShape()
                    .fill(Color.white.opacity(isFast ? 0.65 : 0.92))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// MARK: - Линии потока ветра
struct WindStreaksView: View {
    let direction: Double
    let speedKmh: Double
    let beaufort: Int
    let color: Color
    let reduceMotion: Bool

    private var isAnimated: Bool {
        speedKmh >= 1 && !reduceMotion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimated)) { timeline in
            Canvas { context, size in
                let time: Double = isAnimated ? timeline.date.timeIntervalSinceReferenceDate : 0
                drawStreaks(context: &context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawStreaks(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard beaufort > 0 else { return }

        let count: Int = min(2 + beaufort, 8)
        // Ветер дует В сторону, противоположную той, ОТКУДА он дует
        let bearing: Double = (direction + 180) * Double.pi / 180
        let dx: CGFloat = CGFloat(sin(bearing))
        let dy: CGFloat = CGFloat(-cos(bearing))
        let length: CGFloat = hypot(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let flow: Double = 10 + min(speedKmh, 60) * 1.2
        let opacity: Double = 0.10 + Double(min(beaufort, 8)) * 0.012

        for index in 0..<count {
            let share: CGFloat = (CGFloat(index) + 0.5) / CGFloat(count) - 0.5
            let noise: Double = fract(sin(Double(index + 1) * 12.9898) * 43758.5453)
            let jitter: CGFloat = CGFloat(noise - 0.5) * 14
            let shift: CGFloat = share * length * 0.8 + jitter

            // (-dy, dx) перпендикулярно направлению ветра
            let middle = CGPoint(x: center.x - dy * shift, y: center.y + dx * shift)

            var path = Path()
            path.move(to: CGPoint(x: middle.x - dx * length / 2, y: middle.y - dy * length / 2))
            path.addLine(to: CGPoint(x: middle.x + dx * length / 2, y: middle.y + dy * length / 2))

            let travelled: Double = (time * flow).truncatingRemainder(dividingBy: 68)
            let phase: CGFloat = CGFloat(-travelled) + CGFloat(index) * 17
            let style = StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [28, 40], dashPhase: phase)
            context.stroke(path, with: .color(color.opacity(opacity)), style: style)
        }
    }
}

// MARK: - Фигура ветряка (3 изогнутые лопасти)
struct FanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r: CGFloat = min(rect.width, rect.height) / 2

        // Одна лопасть, направленная вверх
        var blade = Path()
        blade.move(to: CGPoint(x: c.x, y: c.y - r * 0.10))
        blade.addQuadCurve(
            to: CGPoint(x: c.x + r * 0.03, y: c.y - r),
            control: CGPoint(x: c.x + r * 0.27, y: c.y - r * 0.5)
        )
        blade.addQuadCurve(
            to: CGPoint(x: c.x - r * 0.10, y: c.y - r * 0.10),
            control: CGPoint(x: c.x - r * 0.23, y: c.y - r * 0.55)
        )
        blade.closeSubpath()

        // Три копии, повёрнутые вокруг центра на 120°
        for index in 0..<3 {
            let turn: CGFloat = CGFloat(index) * 2 * CGFloat.pi / 3
            let transform = CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: turn)
                .translatedBy(x: -c.x, y: -c.y)
            path.addPath(blade, transform: transform)
        }
        return path
    }
}
struct HumidityPanel: View {
    let humidity: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var descriptor: String {
        switch humidity {
        case ..<30: return "Dry"
        case 30..<60: return "Comfortable"
        case 60..<80: return "Humid"
        default: return "Very humid"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Стекло лежит на ВСЕЙ карточке, а не внутри отступов
            GlassDropsView(humidity: humidity, reduceMotion: reduceMotion)

            VStack(alignment: .leading, spacing: 10) {
                Text("HUMIDITY")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(AtmosPalette.secondaryText)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(humidity)")
                            .font(.system(size: 34, weight: .light, design: .rounded))
                        Text("%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AtmosPalette.secondaryText)
                    }
                    Text(descriptor)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AtmosPalette.secondaryText)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 250, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Humidity \(humidity) percent, \(descriptor)")
    }
}

// MARK: - Стекло с каплями
struct GlassDropsView: View {
    let humidity: Int
    let reduceMotion: Bool

    // С какой влажности капли начинают стекать
    private static let slideFrom: Int = 60

    // static let создаётся ОДИН раз, поэтому капли не «прыгают» при обновлении экрана
    private static let staticDrops: [Drop] = (0..<80).map { (i: Int) -> Drop in
        let n: Double = Double(i + 1)
        let x: CGFloat = CGFloat(fract(sin(n * 12.9898) * 43758.5453)) * 0.9 + 0.05
        let y: CGFloat = CGFloat(fract(sin(n * 78.233) * 12345.6789)) * 0.9 + 0.05
        let r: CGFloat = 1.2 + CGFloat(fract(sin(n * 39.346) * 9876.543)) * 2.4
        return Drop(x: x, y: y, radius: r, speed: 0, offset: 0)
    }

    private static let slidingDrops: [Drop] = (0..<12).map { (i: Int) -> Drop in
        let n: Double = Double(i + 1)
        let x: CGFloat = CGFloat(fract(sin(n * 21.17) * 43758.5453)) * 0.8 + 0.1
        let r: CGFloat = 2.2 + CGFloat(fract(sin(n * 9.31) * 12345.6789)) * 1.6
        let s: CGFloat = 0.05 + CGFloat(fract(sin(n * 4.77) * 9876.543)) * 0.10
        let o: CGFloat = CGFloat(fract(sin(n * 15.61) * 3456.789))
        return Drop(x: x, y: 0, radius: r, speed: s, offset: o)
    }

    private var isAnimated: Bool {
        humidity >= Self.slideFrom && !reduceMotion
    }

    var body: some View {
        // paused: true значит «нарисуй один раз и больше не обновляй»
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimated)) { timeline in
            Canvas { context, size in
                drawGlass(
                    context: &context,
                    size: size,
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
    }

    private func drawGlass(context: inout GraphicsContext, size: CGSize, time: Double) {
        let h: Double = Double(humidity)
        let fogOpacity: Double = max(0, (h - 30) / 70) * 0.25
        let sliding: [Drop] = isAnimated ? Self.slidingDrops : []

        // 1. Туман и протёртые дорожки рисуются в одном слое
        context.drawLayer { layer in
            layer.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white.opacity(fogOpacity))
            )

            // Всё, что рисуем дальше, СТИРАЕТ туман, а не закрашивает его
            layer.blendMode = .destinationOut

            for drop in sliding {
                let head: CGPoint = slidePosition(drop: drop, time: time, size: size)
                let tail = CGPoint(x: head.x, y: head.y - 70)

                var trail = Path()
                trail.move(to: tail)
                trail.addLine(to: head)

                let fade = Gradient(colors: [Color.black.opacity(0), Color.black])
                let shading = GraphicsContext.Shading.linearGradient(fade, startPoint: tail, endPoint: head)
                let style = StrokeStyle(lineWidth: drop.radius * 1.4, lineCap: .round)
                layer.stroke(trail, with: shading, style: style)
            }
        }

        // 2. Неподвижные капли: чем выше влажность, тем их больше и они крупнее
        let count: Int = Int(h / 100.0 * 40)
        let scale: CGFloat = CGFloat(0.5 + h / 100.0 * 0.9)
        for i in 0..<count {
            let drop: Drop = Self.staticDrops[i]
            let center = CGPoint(x: drop.x * size.width, y: drop.y * size.height)
            let diameter: CGFloat = drop.radius * scale * 2
            drawDrop(&context, center: center, width: diameter, height: diameter, alpha: 0.18)
        }

        // 3. Стекающие капли (головы дорожек)
        for drop in sliding {
            let head: CGPoint = slidePosition(drop: drop, time: time, size: size)
            drawDrop(&context, center: head, width: drop.radius * 1.8, height: drop.radius * 2.5, alpha: 0.35)
        }
    }

    private func slidePosition(drop: Drop, time: Double, size: CGSize) -> CGPoint {
        let boost: Double = 1.0 + Double(humidity - Self.slideFrom) / 40.0
        let speed: Double = Double(drop.speed) * boost
        let progress: Double = (time * speed + Double(drop.offset)).truncatingRemainder(dividingBy: 1.0)
        return CGPoint(x: drop.x * size.width, y: CGFloat(progress) * size.height)
    }

    private func drawDrop(_ context: inout GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat, alpha: Double) {
        let body = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        context.fill(Path(ellipseIn: body), with: .color(Color.white.opacity(alpha)))
        context.stroke(Path(ellipseIn: body), with: .color(Color.white.opacity(0.35)), lineWidth: 0.6)

        let shine = CGRect(x: center.x - width * 0.3, y: center.y - height * 0.3, width: width * 0.3, height: height * 0.3)
        context.fill(Path(ellipseIn: shine), with: .color(Color.white.opacity(0.8)))
    }
}


// Модель капли (оставь без изменений)
struct Drop {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let speed: CGFloat
    let offset: CGFloat
}

// MARK: - Daily
struct DailyForecast: View {
    let daily: DailyWeather
    private var count: Int { min(daily.time.count, daily.temperature_2m_max.count, daily.temperature_2m_min.count, daily.weather_code.count, 7) }
    var body: some View {
        if count > 0 {
            let highs = Array(daily.temperature_2m_max.prefix(count))
            let lows = Array(daily.temperature_2m_min.prefix(count))
            let weekMin = lows.min() ?? 0
            let weekMax = highs.max() ?? 1
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "\(count)-DAY FORECAST", icon: "calendar").padding(.bottom, 6)
                ForEach(0..<count, id: \.self) { index in
                    DailyRow(day: index == 0 ? "Today" : AtmosFormat.weekday(daily.time[index]), symbol: SkyCondition(code: daily.weather_code[index]).symbol(isDay: true), low: lows[index], high: highs[index], weekMin: weekMin, weekMax: weekMax)
                    if index < count - 1 { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
                }
            }
        }
    }
}

struct DailyRow: View {
    let day: String; let symbol: String; let low: Double; let high: Double; let weekMin: Double; let weekMax: Double
    var body: some View {
        HStack(spacing: 12) {
            Text(day).font(.system(size: 17, weight: .medium, design: .rounded)).frame(width: 56, alignment: .leading)
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.system(size: 20)).frame(width: 30)
            Text(AtmosFormat.degrees(low)).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(AtmosPalette.secondaryText).frame(width: 40, alignment: .trailing)
            RangeBar(low: low, high: high, weekMin: weekMin, weekMax: weekMax)
            Text(AtmosFormat.degrees(high)).font(.system(size: 16, weight: .semibold, design: .rounded)).frame(width: 40, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}

struct RangeBar: View {
    let low: Double; let high: Double; let weekMin: Double; let weekMax: Double
    var body: some View {
        GeometryReader { geo in
            let span = max(weekMax - weekMin, 0.1)
            let start = CGFloat((low - weekMin) / span)
            let end = CGFloat((high - weekMin) / span)
            let barWidth = max(8, geo.size.width * (end - start))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(LinearGradient(colors: [AtmosPalette.cyan, AtmosPalette.amber], startPoint: .leading, endPoint: .trailing))
                    .frame(width: barWidth).offset(x: min(geo.size.width * start, geo.size.width - barWidth))
            }
        }.frame(height: 5)
    }
}

// MARK: - Sun
struct SunSection: View {
    let current: CurrentWeather
    let daily: DailyWeather
    let fetchedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            // Вызываем отдельную функцию для расчетов
            buildContent(for: timeline.date)
        }
    }

    @ViewBuilder
    private func buildContent(for date: Date) -> some View {
        let elapsed = date.timeIntervalSince(fetchedAt)
        let formatter = SunSection.dateFormatter
        let simulatedNow = formatter.date(from: current.time)?.addingTimeInterval(elapsed)
        
        // Безопасно извлекаем данные
        if let simulatedNow = simulatedNow,
           let currentTimeStr = Optional(formatter.string(from: simulatedNow)),
           let dayIndex = daily.time.firstIndex(where: { $0 == String(currentTimeStr.prefix(10)) }),
           daily.sunrise.indices.contains(dayIndex),
           daily.sunset.indices.contains(dayIndex),
           let riseMinutes = AtmosFormat.minutes(daily.sunrise[dayIndex]),
           let setMinutes = AtmosFormat.minutes(daily.sunset[dayIndex]),
           setMinutes > riseMinutes {
            
            let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: simulatedNow)
            let nowMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            
            // День или ночь
            let isDay = nowMinutes >= riseMinutes && nowMinutes < setMinutes
            
            // Прогресс
            let nightDuration = (24 * 60 - setMinutes) + riseMinutes
            let timeSinceSunset = nowMinutes >= setMinutes ? (nowMinutes - setMinutes) : (24 * 60 - setMinutes + nowMinutes)
            
            let progress = isDay
                ? Double(nowMinutes - riseMinutes) / Double(setMinutes - riseMinutes)
                : Double(timeSinceSunset) / Double(nightDuration)
            
            let daylight = setMinutes - riseMinutes
            
            // Сама вьюха
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "SUN & MOON", icon: "moon.stars.fill")
                
                SunArc(progress: progress, isDay: isDay)
                    .frame(height: 130)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Sunrise", systemImage: "sunrise.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AtmosPalette.secondaryText)
                        Text(AtmosFormat.clock(daily.sunrise[dayIndex]))
                            .font(.system(size: 22, weight: .light, design: .rounded))
                    }
                    
                    Spacer()
                    
                    Text("\(daylight / 60)h \(daylight % 60)m of daylight")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AtmosPalette.tertiaryText)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Label("Sunset", systemImage: "sunset.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AtmosPalette.secondaryText)
                        Text(AtmosFormat.clock(daily.sunset[dayIndex]))
                            .font(.system(size: 22, weight: .light, design: .rounded))
                    }
                }
            }
        }
    }
}

struct SunArc: View {
    let progress: Double
    let isDay: Bool

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width / 2 - 16, 112)
            let centerX = geo.size.width / 2
            let centerY = radius + 8
            let clamped = min(max(progress, 0), 1)
            let angle = Double.pi * (1 - clamped)
            let dotX = centerX + radius * CGFloat(cos(angle))
            let dotY = centerY - radius * CGFloat(sin(angle))

            ZStack {
                // Линия горизонта
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: radius * 2 + 32, height: 1)
                    .position(x: centerX, y: centerY)

                // Пунктирная дуга
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: centerX, y: centerY)

                // Пройденный путь
                Circle()
                    .trim(from: 0.5, to: 0.5 + 0.5 * CGFloat(clamped))
                    .stroke(
                        LinearGradient(
                            colors: isDay ? [AtmosPalette.amber.opacity(0.2), AtmosPalette.amber] : [AtmosPalette.cyan.opacity(0.2), AtmosPalette.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: centerX, y: centerY)

                // Солнце или Луна
                Circle()
                    .fill(isDay ? AtmosPalette.amber : Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: isDay ? AtmosPalette.amber.opacity(0.9) : Color.white.opacity(0.8), radius: 10)
                    .position(x: dotX, y: dotY)
            }
        }
        .accessibilityHidden(true)
    }
}
// MARK: - Shared
extension SunSection {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()
}
struct SectionLabel: View {
    let title: String; let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).kerning(2.5)
        }.foregroundStyle(AtmosPalette.secondaryText).accessibilityAddTraits(.isHeader)
    }
}

struct FooterView: View {
    let updated: String
    var body: some View {
        Text("Open-Meteo · Updated \(AtmosFormat.clock(updated))").font(.system(size: 11, weight: .medium)).foregroundStyle(AtmosPalette.tertiaryText).frame(maxWidth: .infinity).padding(.top, 4)
    }
}

// MARK: - Background
struct AtmosBackground: View {
    let glow: Color; let showStars: Bool; var condition: SkyCondition?; var isDay: Bool = false; var temperatureC: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion; @State private var drift = false

    private var topColor: Color {
        guard let condition else { return AtmosPalette.deepNavy }
        switch (condition, isDay) {
        case (.clear, true): return Color(red: 0.14, green: 0.42, blue: 0.78); case (.clear, false): return AtmosPalette.deepNavy
        case (.partlyCloudy, true): return Color(red: 0.13, green: 0.34, blue: 0.62); case (.partlyCloudy, false): return Color(red: 0.04, green: 0.06, blue: 0.15)
        case (.cloudy, true): return Color(red: 0.22, green: 0.30, blue: 0.44); case (.cloudy, false): return Color(red: 0.08, green: 0.13, blue: 0.24)
        case (.fog, true): return Color(red: 0.32, green: 0.36, blue: 0.46); case (.fog, false): return Color(red: 0.12, green: 0.16, blue: 0.24)
        case (.drizzle, true), (.rain, true): return Color(red: 0.16, green: 0.28, blue: 0.44); case (.drizzle, false), (.rain, false): return Color(red: 0.03, green: 0.10, blue: 0.22)
        case (.snow, true): return Color(red: 0.48, green: 0.56, blue: 0.70); case (.snow, false): return Color(red: 0.14, green: 0.22, blue: 0.38)
        case (.thunderstorm, true): return Color(red: 0.24, green: 0.16, blue: 0.42); case (.thunderstorm, false): return Color(red: 0.09, green: 0.04, blue: 0.20)
        }
    }
    private var midColor: Color {
        guard let condition else { return AtmosPalette.midnight }
        switch (condition, isDay) {
        case (.clear, true): return Color(red: 0.30, green: 0.54, blue: 0.82); case (.clear, false): return AtmosPalette.midnight
        case (.partlyCloudy, true): return Color(red: 0.22, green: 0.42, blue: 0.66); case (.partlyCloudy, false): return Color(red: 0.06, green: 0.10, blue: 0.22)
        case (.cloudy, true): return Color(red: 0.30, green: 0.38, blue: 0.52); case (.cloudy, false): return Color(red: 0.12, green: 0.18, blue: 0.30)
        case (.fog, true): return Color(red: 0.40, green: 0.44, blue: 0.54); case (.fog, false): return Color(red: 0.16, green: 0.20, blue: 0.28)
        case (.drizzle, true), (.rain, true): return Color(red: 0.22, green: 0.34, blue: 0.50); case (.drizzle, false), (.rain, false): return Color(red: 0.05, green: 0.13, blue: 0.26)
        case (.snow, true): return Color(red: 0.58, green: 0.66, blue: 0.78); case (.snow, false): return Color(red: 0.22, green: 0.32, blue: 0.50)
        case (.thunderstorm, true): return Color(red: 0.32, green: 0.22, blue: 0.50); case (.thunderstorm, false): return Color(red: 0.14, green: 0.08, blue: 0.28)
        }
    }
    // Жара: только днём и только при ясном/облачном небе. Дождь, снег, гроза, туман не трогаем
    private var heatLevel: Double {
        guard let temperatureC = temperatureC, isDay, let condition = condition else { return 0 }
        switch condition {
        case .clear, .partlyCloudy, .cloudy: break
        default: return 0
        }
        let x: Double = min(1, max(0, (temperatureC - 30) / 12))
        return x * x * (3 - 2 * x) * 0.9
    }

    private func mixed(_ a: Color, _ b: Color, _ amount: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k: CGFloat = CGFloat(amount)
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k))
    }

    private var heatTop: Color { mixed(topColor, Color(red: 0.72, green: 0.16, blue: 0.10), heatLevel) }
    private var heatMid: Color { mixed(midColor, Color(red: 0.88, green: 0.32, blue: 0.14), heatLevel) }
    private var heatBottom: Color { mixed(bottomColor, Color(red: 0.95, green: 0.50, blue: 0.18), heatLevel) }
    
    // Мороз: азотный эффект, только при ясном/облачном небе
    private var coldLevel: Double {
        guard let temperatureC = temperatureC, let condition = condition else { return 0 }
        switch condition {
        case .clear, .partlyCloudy, .cloudy: break
        default: return 0
        }
        let x: Double = min(1, max(0, (-28 - temperatureC) / 17))
        return x * x * (3 - 2 * x) * 0.92
    }

    private var skyTop: Color { mixed(heatTop, Color(red: 0.02, green: 0.05, blue: 0.26), coldLevel) }
    private var skyMid: Color { mixed(heatMid, Color(red: 0.03, green: 0.12, blue: 0.42), coldLevel) }
    private var skyBottom: Color { mixed(heatBottom, Color(red: 0.06, green: 0.26, blue: 0.62), coldLevel) }
    private var bottomColor: Color {
        guard let condition else { return AtmosPalette.indigo }
        switch (condition, isDay) {
        case (.clear, true): return Color(red: 0.78, green: 0.58, blue: 0.32); case (.clear, false): return AtmosPalette.indigo
        case (.partlyCloudy, true): return Color(red: 0.44, green: 0.38, blue: 0.46); case (.partlyCloudy, false): return Color(red: 0.10, green: 0.12, blue: 0.28)
        case (.cloudy, true): return Color(red: 0.40, green: 0.42, blue: 0.48); case (.cloudy, false): return Color(red: 0.16, green: 0.20, blue: 0.30)
        case (.fog, true): return Color(red: 0.50, green: 0.50, blue: 0.55); case (.fog, false): return Color(red: 0.20, green: 0.24, blue: 0.32)
        case (.drizzle, true), (.rain, true): return Color(red: 0.32, green: 0.40, blue: 0.50); case (.drizzle, false), (.rain, false): return Color(red: 0.06, green: 0.14, blue: 0.24)
        case (.snow, true): return Color(red: 0.68, green: 0.74, blue: 0.84); case (.snow, false): return Color(red: 0.28, green: 0.38, blue: 0.56)
        case (.thunderstorm, true): return Color(red: 0.42, green: 0.30, blue: 0.58); case (.thunderstorm, false): return Color(red: 0.18, green: 0.10, blue: 0.34)
        }
    }

    var body: some View {
        LinearGradient(colors: [skyTop, skyMid, skyBottom], startPoint: .top, endPoint: .bottom)
            .overlay(
                ZStack {
                    Circle().fill(glow.opacity(0.24)).frame(width: 380, height: 380).blur(radius: 90).offset(x: -130, y: drift ? -240 : -290)
                    Circle().fill(AtmosPalette.violet.opacity(0.16)).frame(width: 420, height: 420).blur(radius: 100).offset(x: 150, y: drift ? 300 : 360)
                }
            )
            .overlay(Group { if showStars { StarField() } })
            .clipped().ignoresSafeArea()
            .onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { drift = true } }
            .animation(.easeInOut(duration: 0.8), value: topColor).animation(.easeInOut(duration: 0.8), value: heatTop).animation(.easeInOut(duration: 0.8), value: heatMid).animation(.easeInOut(duration: 0.8), value: heatBottom)
    }
}

struct StarField: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<60 {
                let seed = Double(i) + 1
                let x = CGFloat(fract(sin(seed * 12.9898) * 43758.5453)) * size.width
                let y = CGFloat(fract(sin(seed * 78.233) * 12345.6789)) * size.height * 0.6
                let r = 0.6 + CGFloat(fract(sin(seed * 39.346) * 9876.543)) * 1.2
                let alpha = 0.2 + fract(sin(seed * 5.123) * 3456.789) * 0.5
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(alpha)))
            }
        }.allowsHitTesting(false)
    }
}

// MARK: - Loading and Error
struct LoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion; @State private var pulse = false
    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(AtmosPalette.cyan.opacity(0.25)).frame(width: 120, height: 120).blur(radius: 24).scaleEffect(pulse ? 1.15 : 0.85)
                Circle().strokeBorder(AtmosPalette.cyan.opacity(0.6), lineWidth: 1).frame(width: 64, height: 64)
                ProgressView().tint(AtmosPalette.cyan)
            }
            Text("ATMOS").font(.system(size: 12, weight: .semibold, design: .rounded)).kerning(5).foregroundStyle(AtmosPalette.cyan)
            Text("Reading the atmosphere…").font(.system(size: 15, weight: .medium)).foregroundStyle(AtmosPalette.secondaryText)
        }.onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

struct ErrorView: View {
    let message: String; let retry: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 40, weight: .light)).foregroundStyle(AtmosPalette.amber)
            Text("Weather unavailable").font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(message).font(.system(size: 15)).multilineTextAlignment(.center).foregroundStyle(AtmosPalette.secondaryText).padding(.horizontal, 40)
            Button(action: retry) {
                Text("Try again").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(LinearGradient(colors: [AtmosPalette.cyan.opacity(0.45), AtmosPalette.violet.opacity(0.45)], startPoint: .leading, endPoint: .trailing)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }.padding(.top, 6)
        }
    }
}

// MARK: - Loading and error


// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { AtmosMainView() }
}

