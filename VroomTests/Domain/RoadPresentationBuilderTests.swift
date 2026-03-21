import Foundation
import Testing

@testable import Vroom

struct RoadPresentationBuilderTests {
    @Test func humanSummaryUsesTimeOfDayAndDominantEvent() {
        let morning = Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 20, hour: 8, minute: 0)
        )!
        let trace = [
            RoutePointSample(
                timestamp: morning,
                coordinate: GeoCoordinate(latitude: 34.0, longitude: -118.0),
                altitudeMeters: 0,
                verticalAccuracy: 5,
                horizontalAccuracy: 5,
                speedKPH: 45,
                courseDegrees: 0,
                headingAccuracy: 5
            ),
            RoutePointSample(
                timestamp: morning.addingTimeInterval(60),
                coordinate: GeoCoordinate(latitude: 34.001, longitude: -118.001),
                altitudeMeters: 0,
                verticalAccuracy: 5,
                horizontalAccuracy: 5,
                speedKPH: 62,
                courseDegrees: 0,
                headingAccuracy: 5
            )
        ]
        let events = [
            DrivingEvent(id: UUID(), driveID: UUID(), type: .hardBrake, severity: .medium, confidence: 1, timestamp: trace[1].timestamp, coordinate: trace[1].coordinate, metadata: [:]),
            DrivingEvent(id: UUID(), driveID: UUID(), type: .hardBrake, severity: .low, confidence: 1, timestamp: trace[1].timestamp, coordinate: trace[1].coordinate, metadata: [:])
        ]

        let summary = DriveSummaryBuilder().makeSummary(trace: trace, events: events)

        #expect(summary.title.contains("Morning"))
        #expect(summary.highlight.contains("hard brake"))
        #expect(summary.eventCount == 2)
    }

    @Test func replayCursorMapsIndexIntoProgressAndDistance() {
        let cursor = RoadPresentationBuilder.replayCursor(trace: PreviewFixtures.traceSamples, index: 2)

        #expect(cursor.index == 2)
        #expect(cursor.progress > 0.6)
        #expect(cursor.speed == "63 kph")
        #expect(cursor.distance != "0.0 km")
    }

    @Test func replayCursorInterpolatesBetweenSamples() {
        let cursor = RoadPresentationBuilder.replayCursor(trace: PreviewFixtures.traceSamples, progress: 1.5)

        #expect(cursor.index == 2)
        #expect(cursor.progress > 0.45)
        #expect(cursor.progress < 0.55)
        #expect(cursor.speed == "60 kph")
    }

    @Test func routePresentationAddsStartFinishEventAndReplayMarkers() {
        let presentation = RoutePresentationBuilder.build(
            trace: PreviewFixtures.traceSamples,
            events: [PreviewFixtures.event],
            replayIndex: 1
        )

        #expect(presentation.path.count == PreviewFixtures.traceSamples.count)
        #expect(presentation.markers.count == 4)
        #expect(presentation.markers.contains(where: { $0.kind == .start }))
        #expect(presentation.markers.contains(where: { $0.kind == .finish }))
        #expect(presentation.markers.contains(where: {
            if case .event(.hardBrake) = $0.kind {
                return true
            }
            return false
        }))
        #expect(presentation.highlightedCoordinate == PreviewFixtures.traceSamples[1].coordinate)
    }

    @Test func routePresentationInterpolatesReplayMarkerForFractionalProgress() {
        let presentation = RoutePresentationBuilder.build(
            trace: PreviewFixtures.traceSamples,
            events: [],
            replayProgress: 1.5
        )

        #expect(abs((presentation.highlightedCoordinate?.latitude ?? 0) - 34.0576) < 0.0001)
        #expect(abs((presentation.highlightedCoordinate?.longitude ?? 0) - (-118.2345)) < 0.0001)
        #expect(presentation.markers.contains(where: { $0.kind == .replay }))
    }
}
