import Foundation
import Testing
@testable import Vroom

struct DriveScoringEngineTests {
    @Test func deductsScorePerEventWeight() {
        let engine = DriveScoringEngine(configuration: .default)
        let driveID = UUID()
        let events = [
            DrivingEvent(id: UUID(), driveID: driveID, type: .hardBrake, severity: .medium, confidence: 1, timestamp: Date(), coordinate: GeoCoordinate(latitude: 0, longitude: 0), metadata: [:]),
            DrivingEvent(id: UUID(), driveID: driveID, type: .gForceSpike, severity: .high, confidence: 1, timestamp: Date(), coordinate: GeoCoordinate(latitude: 0, longitude: 0), metadata: [:])
        ]

        let summary = engine.score(events: events, profile: .casual)

        #expect(summary.overall == 86)
        #expect(summary.deductions[DrivingEventType.hardBrake.rawValue] == 6)
        #expect(summary.deductions[DrivingEventType.gForceSpike.rawValue] == 8)
    }
}
