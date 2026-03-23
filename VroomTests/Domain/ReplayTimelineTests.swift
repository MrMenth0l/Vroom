import Foundation
import Testing

@testable import Vroom

struct ReplayTimelineTests {
    @Test func snapshotInterpolatesUsingElapsedTime() {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let trace = [
            makeSample(timestamp: start, latitude: 34.0, longitude: -118.0, speed: 20),
            makeSample(timestamp: start.addingTimeInterval(10), latitude: 34.001, longitude: -118.001, speed: 40),
            makeSample(timestamp: start.addingTimeInterval(40), latitude: 34.010, longitude: -118.010, speed: 100)
        ]

        let timeline = ReplayTimeline(trace: trace)
        let snapshot = timeline.snapshot(at: 20)

        #expect(snapshot != nil)
        #expect(abs((snapshot?.speedKPH ?? 0) - 60) < 0.1)
        #expect(snapshot?.normalizedProgress == 0.5)
        #expect((snapshot?.distanceMeters ?? 0) > trace[0].coordinate.distance(to: trace[1].coordinate))
    }

    @Test func snapshotClampsPastEndToLastSample() {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let trace = [
            makeSample(timestamp: start, latitude: 34.0, longitude: -118.0, speed: 20),
            makeSample(timestamp: start.addingTimeInterval(15), latitude: 34.010, longitude: -118.010, speed: 80)
        ]

        let timeline = ReplayTimeline(trace: trace)
        let snapshot = timeline.snapshot(at: 100)

        #expect(snapshot?.displayIndex == 1)
        #expect(snapshot?.normalizedProgress == 1)
        #expect(snapshot?.coordinate == trace[1].coordinate)
    }

    @Test func snapshotHandlesZeroDurationSegments() {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let trace = [
            makeSample(timestamp: start, latitude: 34.0, longitude: -118.0, speed: 20),
            makeSample(timestamp: start, latitude: 34.002, longitude: -118.002, speed: 30),
            makeSample(timestamp: start.addingTimeInterval(10), latitude: 34.004, longitude: -118.004, speed: 60)
        ]

        let timeline = ReplayTimeline(trace: trace)
        let snapshot = timeline.snapshot(at: 0)

        #expect(snapshot?.displayIndex == 1)
        #expect(snapshot?.coordinate == trace[1].coordinate)
    }

    @MainActor
    @Test func playbackControllerAppliesSpeedAndCameraTransitions() {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let trace = [
            makeSample(timestamp: start, latitude: 34.0, longitude: -118.0, speed: 20),
            makeSample(timestamp: start.addingTimeInterval(10), latitude: 34.010, longitude: -118.010, speed: 80)
        ]

        let controller = ReplayPlaybackController()
        controller.configure(trace: trace, autoplay: false)

        #expect(controller.cameraMode == .fitRoute)
        #expect(controller.isPlaying == false)

        controller.setSpeed(4)
        controller.togglePlayback()
        controller.advance(by: 0.5)
        #expect(abs(controller.playheadTime - 2) < 0.001)

        controller.toggleFollowMode()
        #expect(controller.cameraMode == .followReplay)

        controller.updateCameraModeAfterManualInteraction()
        #expect(controller.cameraMode == .manual)
    }

    private func makeSample(timestamp: Date, latitude: Double, longitude: Double, speed: Double) -> RoutePointSample {
        RoutePointSample(
            timestamp: timestamp,
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            altitudeMeters: 0,
            verticalAccuracy: 5,
            horizontalAccuracy: 5,
            speedKPH: speed,
            courseDegrees: 0,
            headingAccuracy: 5
        )
    }
}
