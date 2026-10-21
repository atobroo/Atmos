//
//  SavedCity.swift
//  Atmos
//

import Foundation

struct SavedCity: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, country: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    static let astana = SavedCity(
        name: "Astana",
        country: "Kazakhstan",
        latitude: 51.1694,
        longitude: 71.4491
    )

    var displayName: String { "\(name), \(country)" }
}
