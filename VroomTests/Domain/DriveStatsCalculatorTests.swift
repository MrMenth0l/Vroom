import Foundation
import Testing

@testable import Vroom

struct DriveStatsCalculatorTests {
    @Test func calculatesDistanceDurationAverageAndTopSpeed() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endedAt = startedAt.addingTimeInterval(120)
        let samples = [
            sample(time: startedAt, lat: 34.0, lon: -118.0, speed: 36),
            sample(time: startedAt.addingTimeInterval(60), lat: 34.0009, lon: -118.0, speed: 54),
            sample(time: endedAt, lat: 34.0018, lon: -118.0, speed: 72)
        ]

        let stats = DriveStatsCalculator().calculate(samples: samples, startedAt: startedAt, endedAt: endedAt)

        #expect(stats.duration == 120)
        #expect(stats.topSpeedKPH == 72)
        #expect(stats.distanceMeters > 0)
        #expect(stats.averageSpeedKPH > 0)
    }

    private func sample(time: Date, lat: Double, lon: Double, speed: Double) -> RoutePointSample {
        RoutePointSample(
            timestamp: time,
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
