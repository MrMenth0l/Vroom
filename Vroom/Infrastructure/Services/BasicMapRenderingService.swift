import CoreGraphics
import Foundation

struct BasicMapRenderingService: MapRenderingService {
    private let base = DefaultMapRenderingService()

    func summary(for trace: [RoutePointSample], events: [DrivingEvent]) async -> DriveSummary {
        await base.summary(for: trace, events: events)
    }

    func presentation(for trace: [RoutePointSample], events: [DrivingEvent]) async -> RoutePresentation {
        await base.presentation(for: trace, events: events)
    }

    func renderRouteSnapshot(_ request: RouteSnapshotRequest) async -> Data? {
        await base.renderRouteSnapshot(request)
    }

    func renderRouteThumbnail(for trace: [RoutePointSample], events: [DrivingEvent], size: CGSize) async -> Data? {
        await base.renderRouteThumbnail(for: trace, events: events, size: size)
    }
}
