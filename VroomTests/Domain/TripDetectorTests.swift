import Foundation
import Testing

@testable import Vroom

struct TripDetectorTests {
    @Test func startsTripAfterConfiguredMovingSamples() {
        var detector = TripDetector(configuration: .default)
        let baseTime = Date()

        let transitions = [
            detector.ingest(sample: sample(at: baseTime, lat: 34.0, lon: -118.0, speed: 20), motion: .init(timestamp: baseTime, isAutomotive: true, confidence: 0.9)),
            detector.ingest(sample: sample(at: baseTime.addingTimeInterval(1), lat: 34.0001, lon: -118.0001, speed: 22), motion: .init(timestamp: baseTime, isAutomotive: true, confidence: 0.9)),
            detector.ingest(sample: sample(at: baseTime.addingTimeInterval(2), lat: 34.0002, lon: -118.0002, speed: 24), motion: .init(timestamp: baseTime, isAutomotive: true, confidence: 0.9))
        ]

        #expect(transitions[0] == .none)
        #expect(transitions[1] == .none)
        #expect(transitions[2] == .started)
    }

    @Test func stopsTripAfterConfiguredStationarySamples() {
        var detector = TripDetector(configuration: .default)
        let baseTime = Date()
        let transitions = (0..<6).map { offset in
            detector.ingest(sample: sample(at: baseTime.addingTimeInterval(Double(offset)), lat: 34.0, lon: -118.0, speed: 0), motion: nil)
        }

        #expect(transitions.prefix(5).allSatisfy { $0 == .none })
        #expect(transitions[5] == .stopped)
    }

    private func sample(at date: Date, lat: Double, lon: Double, speed: Double) -> RoutePointSample {
        RoutePointSample(
            timestamp: date,
            coordinate: GeoCoordinate(latitude: lat, longitude: lon),
            altitudeMeters: 0,
            verticalAccuracy: 8,
            horizontalAccuracy: 5,
            speedKPH: speed,
            courseDegrees: 0,
            headingAccuracy: 5
        )
    }
}
