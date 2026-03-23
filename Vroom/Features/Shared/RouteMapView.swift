import MapKit
import SwiftUI

enum RouteMapMode: Sendable, Hashable {
    case idle
    case live
    case completed
    case replay(playhead: ReplayMapPlayhead?)
}

enum RouteMapCameraMode: Sendable, Hashable {
    case fitRoute
    case followLatest
    case followReplay
    case manual
}

struct RouteMapView: UIViewRepresentable {
    let trace: [RoutePointSample]
    let events: [DrivingEvent]
    let mode: RouteMapMode
    let cameraMode: RouteMapCameraMode
    let style: AppMapStyle
    let bottomPadding: CGFloat
    var onCameraModeChange: ((RouteMapCameraMode) -> Void)?

    init(
        trace: [RoutePointSample],
        events: [DrivingEvent],
        mode: RouteMapMode,
        cameraMode: RouteMapCameraMode,
        style: AppMapStyle = .standard,
        bottomPadding: CGFloat = 120,
        onCameraModeChange: ((RouteMapCameraMode) -> Void)? = nil
    ) {
        self.trace = trace
        self.events = events
        self.mode = mode
        self.cameraMode = cameraMode
        self.style = style
        self.bottomPadding = bottomPadding
        self.onCameraModeChange = onCameraModeChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isPitchEnabled = true
        mapView.layoutMargins = UIEdgeInsets(top: 72, left: 20, bottom: max(84, bottomPadding), right: 20)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCameraModeChange = onCameraModeChange
        context.coordinator.apply(
            presentation: RoutePresentationBuilder.build(
                trace: trace,
                events: events,
                replayProgress: nil,
                replayPlayhead: {
                    if case .replay(let playhead) = mode {
                        return playhead
                    }
                    return nil
                }()
            ),
            mode: mode,
            cameraMode: cameraMode,
            style: style,
            bottomPadding: bottomPadding,
            to: mapView
        )
    }
}

extension RouteMapView {
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCameraModeChange: ((RouteMapCameraMode) -> Void)?

        private var lastStaticSignature: RouteMapStaticSignature?
        private var lastDynamicSignature: RouteMapDynamicSignature?
        private var lastStyle: AppMapStyle?
        private var replayAnnotation: RouteAnnotation?
        private var isProgrammaticCameraChange = false
        private var lastFitSignature: RouteMapFitSignature?
        private var idleFallbackApplied = false

        func apply(
            presentation: RoutePresentation,
            mode: RouteMapMode,
            cameraMode: RouteMapCameraMode,
            style: AppMapStyle,
            bottomPadding: CGFloat,
            to mapView: MKMapView
        ) {
            mapView.layoutMargins = UIEdgeInsets(top: 72, left: 20, bottom: max(84, bottomPadding), right: 20)
            applyStyle(style, to: mapView)

            let staticSignature = RouteMapStaticSignature(
                path: presentation.path,
                markers: presentation.markers.filter { marker in
                    if case .replay = marker.kind {
                        return false
                    }
                    return true
                }
            )
            let dynamicSignature = RouteMapDynamicSignature(
                mode: mode.kind,
                cameraMode: cameraMode,
                lastCoordinate: presentation.path.last,
                highlight: presentation.highlightedCoordinate,
                bottomPadding: bottomPadding
            )

            if staticSignature != lastStaticSignature {
                lastStaticSignature = staticSignature
                lastFitSignature = nil
                idleFallbackApplied = false
                renderStaticRoute(presentation, on: mapView)
            }

            if dynamicSignature != lastDynamicSignature {
                lastDynamicSignature = dynamicSignature
                updateReplayMarker(for: presentation, on: mapView)
                updateCamera(for: presentation, mode: mode, cameraMode: cameraMode, bottomPadding: bottomPadding, on: mapView)
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard !isProgrammaticCameraChange, isUserInteraction(in: mapView) else { return }
            onCameraModeChange?(.manual)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isProgrammaticCameraChange = false
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? RouteAnnotation else { return nil }

            let identifier = "route-marker-\(annotation.kind)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            view.titleVisibility = .visible
            view.subtitleVisibility = annotation.subtitle == nil ? .hidden : .visible

            switch annotation.kind {
            case .start:
                view.markerTintColor = UIColor(RoadTheme.liveGreen)
                view.glyphImage = UIImage(systemName: "play.fill")
            case .finish:
                view.markerTintColor = UIColor(RoadTheme.warningRed)
                view.glyphImage = UIImage(systemName: "flag.checkered")
            case .replay:
                view.markerTintColor = UIColor(RoadTheme.signalAmber)
                view.glyphImage = UIImage(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
            case .event(let type):
                view.markerTintColor = UIColor(accentColor(for: type))
                view.glyphImage = UIImage(systemName: glyphName(for: type))
            }
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(RoadTheme.electricBlue)
                renderer.lineWidth = 4.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        private func applyStyle(_ style: AppMapStyle, to mapView: MKMapView) {
            guard lastStyle != style else { return }
            lastStyle = style

            switch style {
            case .standard:
                mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
            case .hybrid:
                mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
            case .imagery:
                mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            }
        }

        private func renderStaticRoute(_ presentation: RoutePresentation, on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            replayAnnotation = nil

            if !presentation.path.isEmpty {
                let coordinates = presentation.path.map(\.clCoordinate)
                mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            }

            let annotations = presentation.markers.filter { marker in
                if case .replay = marker.kind {
                    return false
                }
                return true
            }.map(RouteAnnotation.init)
            mapView.addAnnotations(annotations)
        }

        private func updateReplayMarker(for presentation: RoutePresentation, on mapView: MKMapView) {
            let replayMarker = presentation.markers.first { marker in
                if case .replay = marker.kind {
                    return true
                }
                return false
            }

            guard let replayMarker else {
                if let replayAnnotation {
                    mapView.removeAnnotation(replayAnnotation)
                    self.replayAnnotation = nil
                }
                return
            }

            if let replayAnnotation {
                replayAnnotation.coordinate = replayMarker.coordinate.clCoordinate
            } else {
                let annotation = RouteAnnotation(marker: replayMarker)
                replayAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        }

        private func updateCamera(
            for presentation: RoutePresentation,
            mode: RouteMapMode,
            cameraMode: RouteMapCameraMode,
            bottomPadding: CGFloat,
            on mapView: MKMapView
        ) {
            guard !presentation.path.isEmpty else {
                if case .idle = mode, !idleFallbackApplied {
                    idleFallbackApplied = true
                    setRegion(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                        ),
                        animated: false,
                        on: mapView
                    )
                }
                return
            }

            switch cameraMode {
            case .manual:
                return

            case .fitRoute:
                let fitSignature = RouteMapFitSignature(path: presentation.path, bottomPadding: bottomPadding)
                guard fitSignature != lastFitSignature else { return }
                lastFitSignature = fitSignature
                if presentation.path.count == 1, let coordinate = presentation.path.first?.clCoordinate {
                    setRegion(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ),
                        animated: !UIAccessibility.isReduceMotionEnabled,
                        on: mapView
                    )
                } else {
                    let polyline = MKPolyline(coordinates: presentation.path.map(\.clCoordinate), count: presentation.path.count)
                    setVisibleMapRect(
                        polyline.boundingMapRect,
                        edgePadding: UIEdgeInsets(top: 80, left: 34, bottom: max(120, bottomPadding), right: 34),
                        animated: !UIAccessibility.isReduceMotionEnabled,
                        on: mapView
                    )
                }

            case .followLatest:
                guard case .live = mode, let last = presentation.path.last else { return }
                setRegion(
                    MKCoordinateRegion(
                        center: last.clCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    ),
                    animated: !UIAccessibility.isReduceMotionEnabled,
                    on: mapView
                )

            case .followReplay:
                guard case .replay = mode, let highlighted = presentation.highlightedCoordinate else { return }
                setRegion(
                    MKCoordinateRegion(
                        center: highlighted.clCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ),
                    animated: false,
                    on: mapView
                )
            }
        }

        private func setVisibleMapRect(
            _ rect: MKMapRect,
            edgePadding: UIEdgeInsets,
            animated: Bool,
            on mapView: MKMapView
        ) {
            isProgrammaticCameraChange = true
            mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: animated)
        }

        private func setRegion(
            _ region: MKCoordinateRegion,
            animated: Bool,
            on mapView: MKMapView
        ) {
            isProgrammaticCameraChange = true
            mapView.setRegion(region, animated: animated)
        }

        private func isUserInteraction(in mapView: MKMapView) -> Bool {
            mapView.subviews
                .compactMap(\.gestureRecognizers)
                .joined()
                .contains { recognizer in
                    switch recognizer.state {
                    case .began, .changed, .ended:
                        return true
                    default:
                        return false
                    }
                }
        }

        private func accentColor(for type: DrivingEventType) -> Color {
            switch type {
            case .hardBrake, .gForceSpike:
                return RoadTheme.warningRed
            case .hardAcceleration, .speedTrap:
                return RoadTheme.signalAmber
            case .cornering, .speedZone:
                return RoadTheme.electricBlue
            }
        }

        private func glyphName(for type: DrivingEventType) -> String {
            switch type {
            case .hardBrake:
                return "arrow.down.to.line"
            case .hardAcceleration:
                return "arrow.up.to.line"
            case .cornering:
                return "arrow.triangle.branch"
            case .gForceSpike:
                return "waveform.path.ecg"
            case .speedTrap:
                return "bolt.fill"
            case .speedZone:
                return "scope"
            }
        }
    }
}

private extension RouteMapMode {
    var kind: RouteMapModeKind {
        switch self {
        case .idle:
            return .idle
        case .live:
            return .live
        case .completed:
            return .completed
        case .replay:
            return .replay
        }
    }
}

private enum RouteMapModeKind: Hashable {
    case idle
    case live
    case completed
    case replay
}

private struct RouteMapStaticSignature: Hashable {
    let path: [GeoCoordinate]
    let markers: [RouteMarkerPresentation]
}

private struct RouteMapDynamicSignature: Hashable {
    let mode: RouteMapModeKind
    let cameraMode: RouteMapCameraMode
    let lastCoordinate: GeoCoordinate?
    let highlight: GeoCoordinate?
    let bottomPadding: CGFloat
}

private struct RouteMapFitSignature: Hashable {
    let path: [GeoCoordinate]
    let bottomPadding: CGFloat
}

private final class RouteAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let kind: RouteMarkerKind

    init(marker: RouteMarkerPresentation) {
        coordinate = marker.coordinate.clCoordinate
        title = marker.title
        subtitle = marker.subtitle
        kind = marker.kind
    }
}
