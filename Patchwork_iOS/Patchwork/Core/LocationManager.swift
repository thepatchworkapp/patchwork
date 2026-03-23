import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    var authorizationStatus: CLAuthorizationStatus
    var lastErrorMessage: String?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        authorizationStatus = status
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentCoordinate() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        authorizationStatus = status

        let allowsLocation: Bool
        switch status {
        case .authorizedAlways:
            allowsLocation = true
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        case .authorizedWhenInUse:
            allowsLocation = true
#endif
        default:
            allowsLocation = false
        }

        guard allowsLocation else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func geocode(city: String, province: String) async -> CLLocationCoordinate2D? {
        let parts = [city, province]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            return nil
        }

        let query = parts.joined(separator: ", ")

        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, error in
                let message = error?.localizedDescription
                let coordinate = placemarks?.first?.location?.coordinate
                Task { @MainActor in
                    if let message {
                        self.lastErrorMessage = message
                    }
                    continuation.resume(returning: coordinate)
                }
            }
        }
    }

}

extension LocationManager: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status
        authorizationContinuation?.resume(returning: status)
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        locationContinuation?.resume(returning: coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastErrorMessage = error.localizedDescription
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
