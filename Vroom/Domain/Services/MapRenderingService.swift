import CoreGraphics
import Foundation

enum RouteMarkerKind: Hashable, Sendable {
    case start
    case finish
    case event(DrivingEventType)
    case replay
}

struct RouteMarkerPresentation: Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let coordinate: GeoCoordinate
    let kind: RouteMarkerKind
}

struct RoutePresentation: Hashable, Sendable {
    let bounds: GeoBounds
    let path: [GeoCoordinate]
    let markers: [RouteMarkerPresentation]
    let highlightedCoordinate: GeoCoordinate?
}

struct RouteSnapshotRequest: Hashable, Sendable {
    let key: DriveRoutePreviewKey
    let trace: [RoutePointSample]

    init(driveID: UUID, trace: [RoutePointSample], size: CGSize, style: AppMapStyle) {
        key = DriveRoutePreviewKey(driveID: driveID, mapStyle: style, size: size)
        self.trace = trace
    }
}

protocol MapRenderingService: Sendable {
    func summary(for trace: [RoutePointSample], events: [DrivingEvent]) async -> DriveSummary
    func presentation(for trace: [RoutePointSample], events: [DrivingEvent]) async -> RoutePresentation
    func renderRouteSnapshot(_ request: RouteSnapshotRequest) async -> Data?
    func renderRouteThumbnail(for trace: [RoutePointSample], events: [DrivingEvent], size: CGSize) async -> Data?
}
