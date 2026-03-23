import CoreGraphics
import Foundation
import Testing

@testable import Vroom

struct DriveRouteAssetTests {
    @Test func cachePrunesMissingDrivesAndInvalidatesPreviews() {
        let keptDriveID = UUID()
        let removedDriveID = UUID()
        let size = CGSize(width: 120, height: 92)

        var cache = DriveRouteAssetCache()
        cache.setLoadState(.ready(PreviewFixtures.traceSamples), for: keptDriveID)
        cache.setLoadState(.unavailable, for: removedDriveID)
        cache.setPreviewState(.ready(Data([0x01])), for: DriveRoutePreviewKey(driveID: keptDriveID, mapStyle: .standard, size: size))
        cache.setPreviewState(.ready(Data([0x02])), for: DriveRoutePreviewKey(driveID: removedDriveID, mapStyle: .standard, size: size))

        cache.prune(keeping: [keptDriveID])

        #expect(cache.loadState(for: keptDriveID).trace?.count == PreviewFixtures.traceSamples.count)
        #expect(cache.loadState(for: removedDriveID) == .idle)
        #expect(cache.previewState(for: DriveRoutePreviewKey(driveID: removedDriveID, mapStyle: .standard, size: size)) == .idle)

        cache.invalidatePreviews()

        #expect(cache.previewState(for: DriveRoutePreviewKey(driveID: keptDriveID, mapStyle: .standard, size: size)) == .idle)
        #expect(cache.loadState(for: keptDriveID).trace?.count == PreviewFixtures.traceSamples.count)
    }

    @MainActor
    @Test func appStateLoadsPersistedRouteAssets() async throws {
        let container = AppContainer.live(inMemory: true)
        let drive = makeDrive()
        let handle = try await container.routeTraceRepository.openWriter(for: drive.id)

        for sample in PreviewFixtures.traceSamples {
            try await container.routeTraceRepository.append(sample: sample, to: handle)
        }

        _ = try await container.routeTraceRepository.finalize(handle: handle)
        try await container.driveRepository.saveDrive(drive)

        let store = AppStateStore(container: container)
        await store.refreshData()
        await store.ensureRouteAssets(for: drive.id)

        switch store.routeLoadState(for: drive.id) {
        case .ready(let trace):
            #expect(trace.count == PreviewFixtures.traceSamples.count)
            #expect(trace.first?.coordinate == PreviewFixtures.traceSamples.first?.coordinate)
        default:
            Issue.record("Expected persisted route assets to load into a ready state.")
        }
    }

    private func makeDrive() -> Drive {
        let start = PreviewFixtures.traceSamples.first?.timestamp ?? Date()
        let end = PreviewFixtures.traceSamples.last?.timestamp ?? start
        return Drive(
            id: UUID(),
            vehicleID: nil,
            startedAt: start,
            endedAt: end,
            distanceMeters: PreviewFixtures.traceSamples.totalDistanceMeters,
            duration: end.timeIntervalSince(start),
            avgSpeedKPH: PreviewFixtures.traceSamples.averageSpeedKPH,
            topSpeedKPH: PreviewFixtures.traceSamples.topSpeedKPH,
            favorite: false,
            scoreSummary: .unrated,
            traceRef: UUID().uuidString,
            summary: DriveSummary(title: "Replay Test", highlight: "Seeded route", eventCount: 0)
        )
    }
}
