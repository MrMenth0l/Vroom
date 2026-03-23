import CoreGraphics
import Foundation

#if canImport(MapKit) && canImport(UIKit)
import MapKit
import UIKit
#endif

private actor RouteSnapshotCacheStore {
    static let shared = RouteSnapshotCacheStore()

    private var cache: [DriveRoutePreviewKey: Data] = [:]

    func cachedData(for key: DriveRoutePreviewKey) -> Data? {
        cache[key]
    }

    func store(_ data: Data, for key: DriveRoutePreviewKey) {
        cache[key] = data
    }
}

struct DefaultMapRenderingService: MapRenderingService {
    private let summaryBuilder = DriveSummaryBuilder()

    func summary(for trace: [RoutePointSample], events: [DrivingEvent]) async -> DriveSummary {
        summaryBuilder.makeSummary(trace: trace, events: events)
    }

    func presentation(for trace: [RoutePointSample], events: [DrivingEvent]) async -> RoutePresentation {
        RoutePresentationBuilder.build(trace: trace, events: events)
    }

    func renderRouteSnapshot(_ request: RouteSnapshotRequest) async -> Data? {
        guard !request.trace.isEmpty else { return nil }

        if let cached = await RouteSnapshotCacheStore.shared.cachedData(for: request.key) {
            return cached
        }

        let data = await mapSnapshotData(for: request)
            ?? renderAbstractRouteImage(trace: request.trace, events: [], size: request.key.size)

        if let data {
            await RouteSnapshotCacheStore.shared.store(data, for: request.key)
        }

        return data
    }

    func renderRouteThumbnail(for trace: [RoutePointSample], events: [DrivingEvent], size: CGSize) async -> Data? {
        renderAbstractRouteImage(trace: trace, events: events, size: size)
    }

    private func renderAbstractRouteImage(
        trace: [RoutePointSample],
        events: [DrivingEvent],
        size: CGSize
    ) -> Data? {
        guard size.width > 0, size.height > 0, !trace.isEmpty else { return nil }
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let colors = [
                UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            cgContext.setShadow(offset: .zero, blur: 22, color: UIColor(red: 0.42, green: 0.73, blue: 1.0, alpha: 0.35).cgColor)
            cgContext.setStrokeColor(UIColor(red: 0.42, green: 0.73, blue: 1.0, alpha: 1).cgColor)
            cgContext.setLineWidth(7)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            let bounds = trace.geoBounds

            func point(for coordinate: GeoCoordinate) -> CGPoint {
                let xRange = max(bounds.maxLongitude - bounds.minLongitude, 0.00001)
                let yRange = max(bounds.maxLatitude - bounds.minLatitude, 0.00001)
                let x = ((coordinate.longitude - bounds.minLongitude) / xRange) * (size.width - 160) + 80
                let y = size.height - (((coordinate.latitude - bounds.minLatitude) / yRange) * (size.height - 160) + 80)
                return CGPoint(x: x, y: y)
            }

            if let first = trace.first {
                cgContext.move(to: point(for: first.coordinate))
                for sample in trace.dropFirst() {
                    cgContext.addLine(to: point(for: sample.coordinate))
                }
                cgContext.strokePath()
            }

            cgContext.setShadow(offset: .zero, blur: 12, color: UIColor(red: 0.95, green: 0.39, blue: 0.34, alpha: 0.35).cgColor)
            for event in events {
                let point = point(for: event.coordinate)
                cgContext.setFillColor(UIColor(red: 0.95, green: 0.39, blue: 0.34, alpha: 1).cgColor)
                cgContext.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
            }

            if let start = trace.first {
                let startPoint = point(for: start.coordinate)
                cgContext.setFillColor(UIColor(red: 0.27, green: 0.82, blue: 0.57, alpha: 1).cgColor)
                cgContext.fillEllipse(in: CGRect(x: startPoint.x - 8, y: startPoint.y - 8, width: 16, height: 16))
            }

            if let end = trace.last {
                let endPoint = point(for: end.coordinate)
                cgContext.setFillColor(UIColor(red: 0.98, green: 0.66, blue: 0.22, alpha: 1).cgColor)
                cgContext.fillEllipse(in: CGRect(x: endPoint.x - 8, y: endPoint.y - 8, width: 16, height: 16))
            }
        }
        return image.pngData()
        #else
        return nil
        #endif
    }

    private func mapSnapshotData(for request: RouteSnapshotRequest) async -> Data? {
        #if canImport(MapKit) && canImport(UIKit)
        let options = MKMapSnapshotter.Options()
        options.size = request.key.size
        options.region = routeRegion(for: request.trace)
        options.preferredConfiguration = configuration(for: request.key.mapStyle)

        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            let renderer = UIGraphicsImageRenderer(size: request.key.size)
            let image = renderer.image { _ in
                snapshot.image.draw(at: .zero)
                drawRouteOverlay(for: snapshot, trace: request.trace)
            }
            return image.pngData()
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

#if canImport(MapKit) && canImport(UIKit)
private extension DefaultMapRenderingService {
    func configuration(for style: AppMapStyle) -> MKMapConfiguration {
        switch style {
        case .standard:
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .hybrid:
            let configuration = MKHybridMapConfiguration(elevationStyle: .realistic)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .imagery:
            return MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }

    func routeRegion(for trace: [RoutePointSample]) -> MKCoordinateRegion {
        guard let first = trace.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
            )
        }

        guard trace.count > 1 else {
            return MKCoordinateRegion(
                center: first.coordinate.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        let bounds = trace.geoBounds
        let latitudeDelta = max((bounds.maxLatitude - bounds.minLatitude) * 1.45, 0.01)
        let longitudeDelta = max((bounds.maxLongitude - bounds.minLongitude) * 1.45, 0.01)
        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    func drawRouteOverlay(for snapshot: MKMapSnapshotter.Snapshot, trace: [RoutePointSample]) {
        guard !trace.isEmpty else { return }

        let points = trace.map { snapshot.point(for: $0.coordinate.clCoordinate) }
        let path = UIBezierPath()
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }

        UIColor.black.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        UIColor(red: 0.25, green: 0.67, blue: 0.98, alpha: 1).setStroke()
        path.lineWidth = 5
        path.stroke()

        if let start = points.first {
            drawMarker(at: start, fill: UIColor(red: 0.19, green: 0.74, blue: 0.46, alpha: 1), stroke: .white, radius: 6)
        }

        if let end = points.last {
            drawMarker(at: end, fill: UIColor(red: 0.96, green: 0.49, blue: 0.19, alpha: 1), stroke: .white, radius: 6)
        }
    }

    func drawMarker(at point: CGPoint, fill: UIColor, stroke: UIColor, radius: CGFloat) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let path = UIBezierPath(ovalIn: rect)
        stroke.setFill()
        UIBezierPath(ovalIn: rect.insetBy(dx: -2, dy: -2)).fill()
        fill.setFill()
        path.fill()
    }
}
#endif
