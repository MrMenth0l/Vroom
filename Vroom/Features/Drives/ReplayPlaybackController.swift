import Combine
import Foundation

struct ReplayMapPlayhead: Hashable, Sendable {
    let elapsedTime: TimeInterval
    let normalizedProgress: Double
    let timestamp: Date
    let speedKPH: Double
    let distanceMeters: Double
    let coordinate: GeoCoordinate
    let displayIndex: Int
}

struct ReplaySegment: Hashable, Sendable {
    let startElapsedTime: TimeInterval
    let endElapsedTime: TimeInterval
    let startTimestamp: Date
    let endTimestamp: Date
    let startSpeedKPH: Double
    let endSpeedKPH: Double
    let startDistanceMeters: Double
    let endDistanceMeters: Double
    let startCoordinate: GeoCoordinate
    let endCoordinate: GeoCoordinate
    let lowerIndex: Int
    let upperIndex: Int

    var duration: TimeInterval {
        endElapsedTime - startElapsedTime
    }
}

struct ReplayTimeline: Hashable, Sendable {
    let samples: [RoutePointSample]
    let segments: [ReplaySegment]
    let totalDuration: TimeInterval

    init(trace: [RoutePointSample]) {
        samples = trace

        guard let first = trace.first else {
            segments = []
            totalDuration = 0
            return
        }

        var builtSegments: [ReplaySegment] = []
        var cumulativeDistance = 0.0

        for (index, pair) in zip(trace, trace.dropFirst()).enumerated() {
            let segmentDistance = pair.0.coordinate.distance(to: pair.1.coordinate)
            let startElapsed = max(0, pair.0.timestamp.timeIntervalSince(first.timestamp))
            let endElapsed = max(startElapsed, pair.1.timestamp.timeIntervalSince(first.timestamp))
            builtSegments.append(
                ReplaySegment(
                    startElapsedTime: startElapsed,
                    endElapsedTime: endElapsed,
                    startTimestamp: pair.0.timestamp,
                    endTimestamp: pair.1.timestamp,
                    startSpeedKPH: pair.0.speedKPH,
                    endSpeedKPH: pair.1.speedKPH,
                    startDistanceMeters: cumulativeDistance,
                    endDistanceMeters: cumulativeDistance + segmentDistance,
                    startCoordinate: pair.0.coordinate,
                    endCoordinate: pair.1.coordinate,
                    lowerIndex: index,
                    upperIndex: index + 1
                )
            )
            cumulativeDistance += segmentDistance
        }

        segments = builtSegments
        totalDuration = max(0, (trace.last?.timestamp ?? first.timestamp).timeIntervalSince(first.timestamp))
    }

    var canPlay: Bool {
        samples.count > 1 && totalDuration > 0
    }

    func progress(for timestamp: Date) -> Double? {
        guard let elapsed = elapsedTime(for: timestamp), totalDuration > 0 else { return nil }
        return normalizedProgress(for: elapsed)
    }

    func elapsedTime(for timestamp: Date) -> TimeInterval? {
        guard let first = samples.first?.timestamp else { return nil }
        return min(max(timestamp.timeIntervalSince(first), 0), totalDuration)
    }

    func normalizedProgress(for elapsedTime: TimeInterval) -> Double {
        guard totalDuration > 0 else { return samples.count > 1 ? 1 : 0 }
        let clampedTime = min(max(elapsedTime, 0), totalDuration)
        return clampedTime / totalDuration
    }

    func snapshot(at elapsedTime: TimeInterval) -> ReplayMapPlayhead? {
        guard let first = samples.first else { return nil }

        if samples.count == 1 {
            return ReplayMapPlayhead(
                elapsedTime: 0,
                normalizedProgress: 0,
                timestamp: first.timestamp,
                speedKPH: first.speedKPH,
                distanceMeters: 0,
                coordinate: first.coordinate,
                displayIndex: 0
            )
        }

        if totalDuration <= 0 {
            let last = samples.last ?? first
            return ReplayMapPlayhead(
                elapsedTime: 0,
                normalizedProgress: 1,
                timestamp: last.timestamp,
                speedKPH: last.speedKPH,
                distanceMeters: segments.last?.endDistanceMeters ?? 0,
                coordinate: last.coordinate,
                displayIndex: samples.count - 1
            )
        }

        let clampedTime = min(max(elapsedTime, 0), totalDuration)
        let segment = segments.first(where: { clampedTime <= $0.endElapsedTime }) ?? segments.last!
        let fraction: Double
        if segment.duration <= 0 {
            fraction = 1
        } else {
            fraction = min(max((clampedTime - segment.startElapsedTime) / segment.duration, 0), 1)
        }

        return ReplayMapPlayhead(
            elapsedTime: clampedTime,
            normalizedProgress: normalizedProgress(for: clampedTime),
            timestamp: segment.startTimestamp.addingTimeInterval(segment.endTimestamp.timeIntervalSince(segment.startTimestamp) * fraction),
            speedKPH: segment.startSpeedKPH + ((segment.endSpeedKPH - segment.startSpeedKPH) * fraction),
            distanceMeters: segment.startDistanceMeters + ((segment.endDistanceMeters - segment.startDistanceMeters) * fraction),
            coordinate: segment.startCoordinate.interpolated(to: segment.endCoordinate, fraction: fraction),
            displayIndex: fraction >= 0.5 ? segment.upperIndex : segment.lowerIndex
        )
    }
}

enum ReplayPanelState: String {
    case compact
    case expanded
}

@MainActor
final class ReplayPlaybackController: ObservableObject {
    static let speedPresets: [Double] = [0.5, 1, 2, 4, 8]

    @Published private(set) var timeline = ReplayTimeline(trace: [])
    @Published var playheadTime: TimeInterval = 0
    @Published var speedMultiplier = 1.0
    @Published var isPlaying = false
    @Published var cameraMode: RouteMapCameraMode = .fitRoute
    @Published var panelState: ReplayPanelState = .compact

    private var resumeAfterScrub = false

    var currentPlayhead: ReplayMapPlayhead? {
        timeline.snapshot(at: playheadTime)
    }

    var totalDuration: TimeInterval {
        timeline.totalDuration
    }

    var canPlay: Bool {
        timeline.canPlay
    }

    var isFollowingReplay: Bool {
        cameraMode == .followReplay
    }

    func configure(trace: [RoutePointSample], autoplay: Bool) {
        timeline = ReplayTimeline(trace: trace)
        playheadTime = 0
        speedMultiplier = 1
        isPlaying = autoplay && timeline.canPlay
        cameraMode = .fitRoute
        panelState = .compact
        resumeAfterScrub = false
    }

    func clear() {
        configure(trace: [], autoplay: false)
    }

    func startOver() {
        playheadTime = 0
        isPlaying = false
        resumeAfterScrub = false
    }

    func togglePlayback() {
        guard canPlay else { return }
        if reachedEnd {
            playheadTime = 0
        }
        isPlaying.toggle()
    }

    func setSpeed(_ speed: Double) {
        speedMultiplier = speed
    }

    func seek(to elapsedTime: TimeInterval) {
        playheadTime = min(max(elapsedTime, 0), totalDuration)
        if reachedEnd {
            isPlaying = false
        }
    }

    func beginScrubbing() {
        resumeAfterScrub = isPlaying
        isPlaying = false
    }

    func endScrubbing() {
        if resumeAfterScrub && canPlay && !reachedEnd {
            isPlaying = true
        }
        resumeAfterScrub = false
    }

    func advance(by delta: TimeInterval) {
        guard isPlaying, canPlay else { return }

        let advancedTime = playheadTime + (delta * speedMultiplier)
        if advancedTime >= totalDuration {
            playheadTime = totalDuration
            isPlaying = false
            return
        }

        playheadTime = advancedTime
    }

    func toggleFollowMode() {
        cameraMode = isFollowingReplay ? .manual : .followReplay
    }

    func recenter() {
        cameraMode = .fitRoute
    }

    func expandPanel() {
        panelState = .expanded
    }

    func collapsePanel() {
        panelState = .compact
    }

    func updateCameraModeAfterManualInteraction() {
        guard cameraMode == .followReplay || cameraMode == .fitRoute else { return }
        cameraMode = .manual
    }

    private var reachedEnd: Bool {
        totalDuration > 0 && playheadTime >= totalDuration
    }
}
