import CoreLocation
import Foundation

enum LocationSyncCache {
    private static let minimumBackendSyncDistanceMeters: CLLocationDistance = 1_000

    static func cachedCoordinate(for userId: ConvexID) -> CLLocationCoordinate2D? {
        guard let payload = UserDefaults.standard.dictionary(forKey: cacheKey(userId: userId)),
              let lat = payload["lat"] as? Double,
              let lng = payload["lng"] as? Double else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    static func store(_ coordinate: CLLocationCoordinate2D, for userId: ConvexID) {
        UserDefaults.standard.set(
            [
                "lat": coordinate.latitude,
                "lng": coordinate.longitude,
                "updatedAt": Date().timeIntervalSince1970,
            ],
            forKey: cacheKey(userId: userId)
        )
    }

    static func shouldSyncBackend(
        newCoordinate: CLLocationCoordinate2D,
        cachedCoordinate: CLLocationCoordinate2D?
    ) -> Bool {
        guard let cachedCoordinate else {
            return true
        }

        return distance(from: cachedCoordinate, to: newCoordinate) >= minimumBackendSyncDistanceMeters
    }

    static func distance(
        from firstCoordinate: CLLocationCoordinate2D,
        to secondCoordinate: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let firstLocation = CLLocation(
            latitude: firstCoordinate.latitude,
            longitude: firstCoordinate.longitude
        )
        let secondLocation = CLLocation(
            latitude: secondCoordinate.latitude,
            longitude: secondCoordinate.longitude
        )
        return firstLocation.distance(from: secondLocation)
    }

    private static func cacheKey(userId: ConvexID) -> String {
        "Patchwork.lastSyncedLocation.\(userId)"
    }
}
