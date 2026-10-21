//
//  LocationManager.swift
//  Atmos
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: Published

    @Published var city = "Определяем город..."
    @Published var country = ""
    @Published var errorMessage = ""
    @Published var isLoading = false

    /// Последняя найденная точка — из неё соберём SavedCity
    @Published var coordinate: CLLocationCoordinate2D?

    /// Готовый SavedCity после успешного геокодинга
    @Published var resolvedCity: SavedCity?

    // MARK: Private

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    // MARK: Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: Public

    /// Запросить разрешение (если нужно) и получить текущую локацию.
    func requestLocation() {
        isLoading = true
        errorMessage = ""
        resolvedCity = nil

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Location access denied. Enable it in Settings."
        @unknown default:
            isLoading = false
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLoading = false
            return
        }

        coordinate = location.coordinate

        geocoder.reverseGeocodeLocation(location) { [weak self] places, error in
            guard let self else { return }

            Task { @MainActor in
                defer { self.isLoading = false }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let place = places?.first else {
                    self.city = "Unknown city"
                    self.errorMessage = "City not found."
                    return
                }

                let name = place.locality
                    ?? place.subAdministrativeArea
                    ?? place.administrativeArea
                    ?? "Unknown"

                let country = place.country ?? ""

                self.city = name
                self.country = country
                self.resolvedCity = SavedCity(
                    name: name,
                    country: country.isEmpty ? "—" : country,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Location access denied. Enable it in Settings."
        default:
            break
        }
    }
}
