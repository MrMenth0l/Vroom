import Combine
import SwiftUI

struct RouteReplayView: View {
    let drive: Drive

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppStateStore

    @StateObject private var controller = ReplayPlaybackController()
    @State private var lastTickEventID: UUID?

    private let playbackTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var currentDrive: Drive {
        appState.drives.first(where: { $0.id == drive.id }) ?? drive
    }

    private var routeState: DriveRouteLoadState {
        appState.routeLoadState(for: drive.id)
    }

    private var sortedEvents: [DrivingEvent] {
        appState.events(for: drive.id).sorted(by: { $0.timestamp < $1.timestamp })
    }

    private var cursor: ReplayCursorPresentation {
        RoadPresentationBuilder.replayCursor(playhead: controller.currentPlayhead)
    }

    private var eventMarkers: [ReplayEventMarker] {
        sortedEvents.compactMap { event in
            guard let progress = controller.timeline.progress(for: event.timestamp) else { return nil }
            return ReplayEventMarker(id: event.id, progress: progress, accent: accent(for: event.type))
        }
    }

    private var sliderUpperBound: Double {
        max(controller.totalDuration, 0.001)
    }

    private var mapBottomPadding: CGFloat {
        controller.panelState == .compact ? 208 : 340
    }

    private var reachedEvent: DrivingEvent? {
        guard let timestamp = controller.currentPlayhead?.timestamp else { return nil }
        return sortedEvents.last(where: { $0.timestamp <= timestamp })
    }

    private var upcomingEvent: DrivingEvent? {
        guard let timestamp = controller.currentPlayhead?.timestamp else { return sortedEvents.first }
        return sortedEvents.first(where: { $0.timestamp > timestamp })
    }

    var body: some View {
        ZStack {
            replayMapSurface

            LinearGradient(
                colors: [RoadTheme.mapScrimTop, .clear, RoadTheme.mapScrimBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("Replay")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            replayPanel
                .padding(.horizontal, RoadSpacing.regular)
                .padding(.top, RoadSpacing.small)
                .padding(.bottom, RoadSpacing.small)
                .background(Color.clear)
        }
        .task(id: drive.id) {
            await loadReplayAssets()
        }
        .onReceive(playbackTimer) { _ in
            let previousTime = controller.playheadTime
            controller.advance(by: 0.05)
            triggerTickFeedbackIfNeeded(from: previousTime, to: controller.playheadTime)
            triggerCompletionFeedbackIfNeeded(from: previousTime, to: controller.playheadTime)
        }
        .onChange(of: appState.preferences.replayAutoplay) { _, newValue in
            if !newValue {
                controller.isPlaying = false
            } else if controller.canPlay && controller.playheadTime < controller.totalDuration {
                controller.isPlaying = true
            }
        }
        .onDisappear {
            controller.isPlaying = false
        }
        .accessibilityIdentifier("Replay.Screen")
    }

    @ViewBuilder
    private var replayMapSurface: some View {
        switch routeState {
        case .idle, .loading:
            RouteMapStatusView(
                title: "Loading replay",
                subtitle: "Preparing the route before replay controls come online.",
                icon: "point.3.filled.connected.trianglepath",
                showsProgress: true
            )
            .ignoresSafeArea(edges: .bottom)

        case .ready(let trace):
            RouteMapView(
                trace: trace,
                events: sortedEvents,
                mode: .replay(playhead: controller.currentPlayhead),
                cameraMode: controller.cameraMode,
                style: appState.preferences.mapStyle,
                bottomPadding: mapBottomPadding,
                onCameraModeChange: { _ in
                    controller.updateCameraModeAfterManualInteraction()
                }
            )
            .ignoresSafeArea(edges: .bottom)

        case .unavailable:
            RouteMapStatusView(
                title: "Replay unavailable",
                subtitle: "This drive does not have enough route detail to replay.",
                icon: "play.slash",
                tone: .warning
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var replayPanel: some View {
        RoadHeroPanel {
            VStack(alignment: .leading, spacing: RoadSpacing.regular) {
                panelHeader
                replayScrubber
                transportControls
                cameraControls

                if controller.panelState == .expanded {
                    speedControls
                    expandedPanelContent
                }

                if !replayUnavailableMessage.isEmpty {
                    Text(replayUnavailableMessage)
                        .font(RoadTypography.caption)
                        .foregroundStyle(RoadTheme.textMuted)
                }
            }
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: RoadSpacing.compact) {
            VStack(alignment: .leading, spacing: RoadSpacing.xSmall) {
                Text(currentDrive.summary.title)
                    .font(RoadTypography.sectionTitle)
                    .foregroundStyle(RoadTheme.textPrimary)

                Text(routeHeaderSubtitle)
                    .font(RoadTypography.meta)
                    .foregroundStyle(RoadTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
                if controller.panelState == .compact {
                    controller.expandPanel()
                } else {
                    controller.collapsePanel()
                }
            } label: {
                Image(systemName: controller.panelState == .compact ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            }
            .buttonStyle(RoadIconButtonStyle(tint: RoadTheme.primaryAction, fill: RoadTheme.primaryFill))
            .accessibilityIdentifier("Replay.PanelToggle")
        }
    }

    private var replayScrubber: some View {
        VStack(alignment: .leading, spacing: RoadSpacing.xSmall) {
            Slider(
                value: Binding(
                    get: { controller.playheadTime },
                    set: { controller.seek(to: $0) }
                ),
                in: 0...sliderUpperBound,
                onEditingChanged: { isEditing in
                    if isEditing {
                        controller.beginScrubbing()
                    } else {
                        controller.endScrubbing()
                    }
                }
            )
            .tint(RoadTheme.primaryAction)
            .disabled(!controller.canPlay)

            ReplayEventTicks(markers: eventMarkers)
                .frame(height: 8)

            HStack {
                Text(cursor.elapsedTime)
                    .font(RoadTypography.caption)
                    .foregroundStyle(RoadTheme.textSecondary)

                Spacer(minLength: 0)

                Text(RoadFormatting.playbackTime(controller.totalDuration))
                    .font(RoadTypography.caption)
                    .foregroundStyle(RoadTheme.textMuted)
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: RoadSpacing.compact) {
            Button("Start Over") {
                controller.startOver()
                lastTickEventID = nil
            }
            .buttonStyle(RoadSecondaryButtonStyle())
            .disabled(routeState.trace == nil)
            .accessibilityIdentifier("Replay.StartOver")

            Button(controller.isPlaying ? "Pause" : "Play Route") {
                controller.togglePlayback()
            }
            .buttonStyle(RoadPrimaryButtonStyle())
            .disabled(!controller.canPlay)
            .accessibilityIdentifier("Replay.Toggle")
        }
    }

    private var cameraControls: some View {
        HStack(spacing: RoadSpacing.compact) {
            Button(controller.isFollowingReplay ? "Following" : "Follow") {
                controller.toggleFollowMode()
            }
            .buttonStyle(RoadSubtleButtonStyle(tint: controller.isFollowingReplay ? RoadTheme.success : RoadTheme.info))
            .accessibilityIdentifier("Replay.Follow")

            Button("Recenter") {
                controller.recenter()
            }
            .buttonStyle(RoadSubtleButtonStyle(tint: RoadTheme.primaryAction))
            .accessibilityIdentifier("Replay.Recenter")
        }
    }

    private var speedControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RoadSpacing.compact) {
                ForEach(ReplayPlaybackController.speedPresets, id: \.self) { speed in
                    Button {
                        controller.setSpeed(speed)
                    } label: {
                        RoadSelectableChip(title: replaySpeedTitle(speed), isSelected: controller.speedMultiplier == speed)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Replay.Speed.\(replaySpeedTitle(speed))")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var expandedPanelContent: some View {
        VStack(alignment: .leading, spacing: RoadSpacing.regular) {
            HStack(spacing: RoadSpacing.compact) {
                replayStat(title: "Speed", value: cursor.speed)
                replayStat(title: "Distance", value: cursor.distance)
                replayStat(title: "Time", value: cursor.elapsedTime)
            }

            replayEventDetail
        }
    }

    @ViewBuilder
    private var replayEventDetail: some View {
        if let reachedEvent {
            RoadInfoRow(
                icon: reachedEvent.type.iconName,
                iconTint: accent(for: reachedEvent.type),
                title: "Latest event: \(reachedEvent.type.displayTitle)",
                subtitle: RoadFormatting.shortDate.string(from: reachedEvent.timestamp)
            ) {
                RoadCapsuleLabel(text: reachedEvent.severity.displayTitle, tint: accent(for: reachedEvent.type))
            }
        } else if let upcomingEvent {
            RoadInfoRow(
                icon: upcomingEvent.type.iconName,
                iconTint: accent(for: upcomingEvent.type),
                title: "Upcoming event: \(upcomingEvent.type.displayTitle)",
                subtitle: RoadFormatting.shortDate.string(from: upcomingEvent.timestamp)
            ) {
                RoadCapsuleLabel(text: upcomingEvent.severity.displayTitle, tint: accent(for: upcomingEvent.type))
            }
        } else {
            Text("No replay events were recorded on this route.")
                .font(RoadTypography.caption)
                .foregroundStyle(RoadTheme.textMuted)
        }
    }

    private var routeHeaderSubtitle: String {
        switch routeState {
        case .idle, .loading:
            return "Preparing replay timeline"
        case .unavailable:
            return "Route unavailable"
        case .ready:
            return "Elapsed \(cursor.elapsedTime) of \(RoadFormatting.playbackTime(controller.totalDuration))"
        }
    }

    private var replayUnavailableMessage: String {
        switch routeState {
        case .unavailable:
            return "Replay needs saved route samples."
        case .ready(let trace):
            return trace.count < 2 ? "Replay needs more route samples." : ""
        case .idle, .loading:
            return "Loading route samples for replay."
        }
    }

    private func loadReplayAssets() async {
        await appState.ensureRouteAssets(for: drive.id)
        configureController()
    }

    private func configureController() {
        switch routeState {
        case .ready(let trace):
            controller.configure(trace: trace, autoplay: appState.preferences.replayAutoplay)
        case .idle, .loading, .unavailable:
            controller.clear()
        }
        lastTickEventID = nil
    }

    private func triggerTickFeedbackIfNeeded(from previousTime: TimeInterval, to currentTime: TimeInterval) {
        guard currentTime >= previousTime else {
            lastTickEventID = nil
            return
        }

        guard let event = sortedEvents.first(where: { event in
            guard let eventElapsed = controller.timeline.elapsedTime(for: event.timestamp) else { return false }
            return eventElapsed > previousTime && eventElapsed <= currentTime
        }) else {
            return
        }

        guard lastTickEventID != event.id else { return }
        lastTickEventID = event.id
        if !reduceMotion {
            RoadFeedback.impact(.light)
        }
    }

    private func triggerCompletionFeedbackIfNeeded(from previousTime: TimeInterval, to currentTime: TimeInterval) {
        guard controller.totalDuration > 0, previousTime < controller.totalDuration, currentTime >= controller.totalDuration else { return }
        RoadFeedback.notify(.success)
    }

    private func replayStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(RoadTypography.caption)
                .foregroundStyle(RoadTheme.textMuted)

            Text(value)
                .font(RoadTypography.label)
                .foregroundStyle(RoadTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RoadSpacing.compact)
        .padding(.vertical, RoadSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: RoadRadius.medium, style: .continuous)
                .fill(RoadTheme.backgroundRaised)
        )
    }

    private func replaySpeedTitle(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))x"
        }
        return "\(speed.formatted(.number.precision(.fractionLength(1))))x"
    }

    private func accent(for type: DrivingEventType) -> Color {
        switch type {
        case .hardBrake, .gForceSpike:
            return RoadTheme.destructive
        case .hardAcceleration, .speedTrap:
            return RoadTheme.warning
        case .cornering, .speedZone:
            return RoadTheme.info
        }
    }
}

private struct ReplayEventMarker: Identifiable {
    let id: UUID
    let progress: Double
    let accent: Color
}

private struct ReplayEventTicks: View {
    let markers: [ReplayEventMarker]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RoadTheme.secondaryAction)
                    .frame(height: 4)
                    .offset(y: 2)

                ForEach(markers) { marker in
                    Capsule()
                        .fill(marker.accent)
                        .frame(width: 3, height: 8)
                        .offset(x: max(0, min(proxy.size.width - 3, proxy.size.width * marker.progress)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
