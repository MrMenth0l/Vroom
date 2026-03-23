import CoreGraphics
import Foundation

enum DriveRouteLoadState: Equatable {
    case idle
    case loading
    case ready([RoutePointSample])
    case unavailable

    var trace: [RoutePointSample]? {
        guard case let .ready(trace) = self else { return nil }
        return trace
    }
}

struct DriveRoutePreviewKey: Hashable, Sendable {
    let driveID: UUID
    let mapStyle: AppMapStyle
    let width: Int
    let height: Int

    init(driveID: UUID, mapStyle: AppMapStyle, size: CGSize) {
        self.driveID = driveID
        self.mapStyle = mapStyle
        width = max(Int(size.width.rounded(.up)), 1)
        height = max(Int(size.height.rounded(.up)), 1)
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

enum DriveRoutePreviewState: Equatable {
    case idle
    case loading
    case ready(Data)
    case unavailable

    var imageData: Data? {
        guard case let .ready(data) = self else { return nil }
        return data
    }
}

struct DriveRouteAssetCache {
    private(set) var loadStates: [UUID: DriveRouteLoadState] = [:]
    private(set) var previewStates: [DriveRoutePreviewKey: DriveRoutePreviewState] = [:]

    func loadState(for driveID: UUID) -> DriveRouteLoadState {
        loadStates[driveID] ?? .idle
    }

    func previewState(for key: DriveRoutePreviewKey) -> DriveRoutePreviewState {
        previewStates[key] ?? .idle
    }

    mutating func setLoadState(_ state: DriveRouteLoadState, for driveID: UUID) {
        loadStates[driveID] = state
    }

    mutating func setPreviewState(_ state: DriveRoutePreviewState, for key: DriveRoutePreviewKey) {
        previewStates[key] = state
    }

    mutating func prune(keeping driveIDs: Set<UUID>) {
        loadStates = loadStates.filter { driveIDs.contains($0.key) }
        previewStates = previewStates.filter { driveIDs.contains($0.key.driveID) }
    }

    mutating func invalidatePreviews() {
        previewStates.removeAll()
    }
}
