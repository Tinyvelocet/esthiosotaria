import Foundation
import CoreLocation

/// Wraps CoreLocation with async/await. Location never leaves the device.
/// If permission is denied, callers must offer manual entry (city/ZIP).
@MainActor
final class LocationService: NSObject, ObservableObject {

    enum LocationStatus {
        case idle
        case requesting
        case granted(CLLocationCoordinate2D)
        case denied
        case failed(String)
    }

    @Published var status: LocationStatus = .idle

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    enum LocationError: Error, LocalizedError, Equatable {
        case denied
        case unknown(String)
        var errorDescription: String? {
            switch self {
            case .denied: return "Location access was denied."
            case .unknown(let detail): return "Could not determine location: \(detail)"
            }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // coarse is plenty
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        status = .requesting
        do {
            let coordinate = try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined:
                    manager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    continuation.resume(throwing: LocationError.denied)
                    self.continuation = nil
                    status = .denied
                default:
                    manager.requestLocation()
                }
            }
            status = .granted(coordinate)
            return coordinate
        } catch let error as LocationError {
            status = (error == .denied) ? .denied : .failed(error.localizedDescription)
            throw error
        } catch {
            status = .failed(error.localizedDescription)
            throw LocationError.unknown(error.localizedDescription)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.continuation = nil
                manager.requestLocation()
            case .denied, .restricted:
                self.continuation = nil
                self.status = .denied
                continuation.resume(throwing: LocationError.denied)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let continuation = self.continuation, let location = locations.first else { return }
            self.continuation = nil
            continuation.resume(returning: location.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.status = .failed(error.localizedDescription)
            continuation.resume(throwing: LocationError.unknown(error.localizedDescription))
        }
    }
}
