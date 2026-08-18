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

    /// Upper bound on how long a single location request may take before we
    /// give up, so a stalled CoreLocation never leaves onboarding hanging.
    private static let timeoutNanoseconds: UInt64 = 30_000_000_000 // 30s

    enum LocationError: Error, LocalizedError, Equatable {
        case denied
        case timedOut
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access was denied."
            case .timedOut: return "Could not get your location in time. Try again or enter a city instead."
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

        // Safety net: if neither delegate callback fires within the budget,
        // resume with a timeout instead of leaving the caller suspended forever.
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.timeoutNanoseconds)
            guard let self, let continuation = self.continuation else { return }
            self.continuation = nil
            self.status = .failed(LocationError.timedOut.localizedDescription)
            continuation.resume(throwing: LocationError.timedOut)
        }
        defer { timeoutTask.cancel() }

        do {
            let coordinate = try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined:
                    manager.requestWhenInUseAuthorization()
                case .authorizedWhenInUse, .authorizedAlways:
                    manager.requestLocation()
                case .denied, .restricted:
                    self.continuation = nil
                    continuation.resume(throwing: LocationError.denied)
                    status = .denied
                @unknown default:
                    manager.requestWhenInUseAuthorization()
                }
            }
            status = .granted(coordinate)
            return coordinate
        } catch let error as LocationError {
            switch error {
            case .denied: status = .denied
            case .timedOut: status = .failed(error.localizedDescription)
            case .unknown(let detail): status = .failed(detail)
            }
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
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Do NOT clear `self.continuation` here — `didUpdateLocations`
                // is what actually resumes it. An earlier version cleared it
                // before calling `requestLocation()`, which orphaned the
                // continuation on a first-time grant and left the caller
                // awaiting forever.
                guard self.continuation != nil else { return }
                manager.requestLocation()
            case .denied, .restricted:
                guard let continuation = self.continuation else { return }
                self.continuation = nil
                self.status = .denied
                continuation.resume(throwing: LocationError.denied)
            default:
                break // .notDetermined is the interim state — keep waiting
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let continuation = self.continuation, let location = locations.last else { return }
            self.continuation = nil
            continuation.resume(returning: location.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // kCLErrorLocationUnknown is transient (no fix yet); retry rather
            // than failing the user.
            guard (error as? CLError)?.code != .locationUnknown else {
                manager.requestLocation()
                return
            }
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.status = .failed(error.localizedDescription)
            continuation.resume(throwing: LocationError.unknown(error.localizedDescription))
        }
    }
}