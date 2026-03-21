import Foundation
import Testing
@testable import Vroom

struct InsightsAggregatorTests {
    @Test func computesSnapshotForRecentDrives() {
        let aggregator = InsightsAggregator()
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let recentDrive = Drive(id: UUID(), vehicleID: nil, startedAt: now.addingTimeInterval(-3_600), endedAt: now, distanceMeters: 10_000, duration: 900, avgSpeedKPH: 50, topSpeedKPH: 90, favorite: false, scoreSummary: DriveScoreSummary(overall: 92, subscores: [:], deductions: [:], profileID: ScoringProfile.casual.id), traceRef: "a", summary: DriveSummary(title: "Recent", highlight: "Clean", eventCount: 2))
        let oldDrive = Drive(id: UUID(), vehicleID: nil, startedAt: now.addingTimeInterval(-900_000), endedAt: now.addingTimeInterval(-899_000), distanceMeters: 3_000, duration: 400, avgSpeedKPH: 30, topSpeedKPH: 55, favorite: false, scoreSummary: DriveScoreSummary(overall: 70, subscores: [:], deductions: [:], profileID: ScoringProfile.casual.id), traceRef: "b", summary: DriveSummary(title: "Old", highlight: "Old", eventCount: 1))
        let events = [DrivingEvent(id: UUID(), driveID: recentDrive.id, type: .hardBrake, severity: .low, confidence: 1, timestamp: now, coordinate: GeoCoordinate(latitude: 0, longitude: 0), metadata: [:])]

        let snapshot = aggregator.snapshot(period: .week, now: now, drives: [recentDrive, oldDrive], events: events)

        #expect(snapshot.distanceTotal == 10_000)
        #expect(snapshot.eventFrequency == 1)
        #expect(snapshot.scoreTrend == 92)
    }
}
