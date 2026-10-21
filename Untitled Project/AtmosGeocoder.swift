//
//  AtmosGeocoder.swift
//  Atmos
//

import Foundation

/// Searches cities via Open-Meteo geocoding API.
/// https://geocoding-api.open-meteo.com/v1/search?name=Astana
enum AtmosGeocoder {

    struct Result: Identifiable, Hashable {
        let id: UUID = UUID()
        let name: String
        let country: String
        let admin1: String?
        let latitude: Double
        let longitude: Double

        var subtitle: String {
            [admin1, country].compactMap { $0 }.joined(separator: ", ")
        }

        var saved: SavedCity {
            SavedCity(
                name: name,
                country: country.isEmpty ? "—" : country,
                latitude: latitude,
                longitude: longitude
            )
        }
    }

    static func search(_ query: String, language: String = "en") async throws -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name: "name", value: trimmed),
            .init(name: "count", value: "8"),
            .init(name: "language", value: language),
            .init(name: "format", value: "json")
        ]

        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (decoded.results ?? []).map {
            Result(
                name: $0.name,
                country: $0.country ?? "",
                admin1: $0.admin1,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }

    // MARK: - Private DTOs

    private struct SearchResponse: Decodable {
        let results: [Entry]?
    }

    private struct Entry: Decodable {
        let name: String
        let country: String?
        let admin1: String?
        let latitude: Double
        let longitude: Double
    }
}
