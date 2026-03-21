import Foundation
import Testing

@testable import Vroom

struct TrapExtractorTests {
    @Test func extractsTrapForFastPeak() {
        let driveID = UUID()
        let extractor = TrapExtractor(configuration: .default)
        let baseTime = Date()
        let samples = [
            makeSample(time: baseTime, speed: 72, latitude: 34.0),
            makeSample(time: baseTime.addingTimeInterval(1), speed: 88, latitude: 34.0001),
            makeSample(time: baseTime.addingTimeInterval(2), speed: 70, latitude: 34.0002)
        ]

        let traps = extractor.extract(driveID: driveID, samples: samples)

        #expect(traps.count == 1)
        #expect(traps.first?.driveID == driveID)
        #expect(traps.first?.peakSpeedKPH == 88)
    }

    private func makeSample(time: Date, speed: Double, latitude: Double) -> RoutePointSample {
        RoutePointSample(
            timestamp: time,
            coordinate: GeoCoordinate(latitude: latitude, longitude: -118),
            altitudeMeters: 0,
            verticalAccuracy: 8,
            horizontalAccuracy: 5,
            speedKPH: speed,
            courseDegrees: 0,
            headingAccuracy: 5
        )
    }
}
