import Foundation
import Testing

@testable import Vroom

struct DrivingEventDetectorTests {
    @Test func emitsBrakeAndCorneringEventsFromMotionAndSpeed() {
        var detector = DrivingEventDetector(configuration: .default)
        let driveID = UUID()
        let start = sample(time: Date(), speed: 70, latitude: 34.0)
        _ = detector.ingest(driveID: driveID, sample: start, motion: .init(timestamp: start.timestamp, lateralG: 0.1, longitudinalG: 0.1))

        let brake = detector.ingest(
            driveID: driveID,
            sample: sample(time: start.timestamp.addingTimeInterval(1), speed: 45, latitude: 34.0001),
            motion: .init(timestamp: start.timestamp.addingTimeInterval(1), lateralG: 0.9, longitudinalG: -0.95)
        )

        #expect(brake.contains(where: { $0.type == .hardBrake }))
        #expect(brake.contains(where: { $0.type == .cornering }))
    }

    private func sample(time: Date, speed: Double, latitude: Double) -> RoutePointSample {
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
