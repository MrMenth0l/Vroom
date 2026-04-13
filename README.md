# Vroom

Vroom is an iPhone-first driving companion built with SwiftUI, SwiftData, Core Location, and StoreKit. It captures routes, tracks active drive state, summarizes completed trips, surfaces driving insights, and lays the foundation for premium and convoy-oriented features without collapsing the codebase into a single app-layer monolith.

The project is structured as a production-style app, not a throwaway prototype. Feature code, domain logic, repositories, platform services, and persistence concerns are separated so the app can keep evolving without rewriting core boundaries.

## Product Scope

Vroom currently includes:

- Onboarding with permission readiness and initial profile and vehicle setup
- Manual and automatic drive session handling
- Route capture with active session restoration
- Drive history, drive summary, and route replay flows
- Insight snapshots and trend surfaces
- Vehicle management and default vehicle selection
- Premium purchase and restore flows through StoreKit
- Local export and local reset utilities
- Convoy preview surfaces with service boundaries already in place

## Tech Stack

- Swift 6-era Xcode project using SwiftUI
- SwiftData for local persistence
- Core Location and Core Motion for drive detection inputs
- StoreKit for premium product loading and purchase flows
- Map rendering and share-card services behind app-owned abstractions
- Async/await and `AsyncStream`-based service coordination

## Architecture

The repository is organized to keep UI concerns, business logic, and platform integrations distinct:

- `Vroom/App`: app entry wiring and root scene composition
- `Vroom/Core`: dependency composition, environment wiring, and logging
- `Vroom/Domain`: models, analysis logic, drive detection, protocols, and service contracts
- `Vroom/Features`: SwiftUI screens and reusable presentation components
- `Vroom/Infrastructure`: repository implementations, sensor adapters, persistence, and concrete services
- `VroomTests`: unit tests for domain and service behavior
- `VroomUITests`: end-to-end UI coverage for core user flows

That split is reflected in the live container: repositories and platform services are composed in [`Vroom/Core/AppContainer.swift`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Vroom/Core/AppContainer.swift), then injected into the app state store and feature layer.

## Core Flows

### Drive Capture

The drive tracking stack combines location, motion activity, and active session coordination:

- `DefaultDriveTrackingService` manages monitoring state and route ingestion
- `DriveSessionCoordinator` owns session lifecycle and persistence handoff
- `TripDetector` handles automatic start and stop heuristics
- `CoreLocationService` provides passive and active location streams with background support

Manual sessions and automatic sessions are intentionally handled differently so explicit user-initiated recording is not stopped by the automatic stop heuristics.

### Post-Drive Experience

After a drive completes, Vroom prepares the data needed to review what happened:

- route history
- replayable traces
- driving events
- speed trap extraction
- zone matching
- weekly and monthly insight snapshots

### Monetization and Feature Gating

Premium-related functionality is wired through app-owned boundaries rather than directly through UI code:

- StoreKit product loading and purchasing
- locally cached subscription snapshot state
- entitlement decisions behind `EntitlementService`

This keeps premium behavior testable and replaceable as the product grows.

## Getting Started

### Requirements

- macOS with Xcode 26.3 or newer
- iOS Simulator or physical iPhone
- iOS deployment target: 17.0

### Run Locally

1. Open [`Vroom.xcodeproj`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Vroom.xcodeproj).
2. Select the `Vroom` scheme.
3. Choose an iPhone simulator or connected device.
4. Build and run.

### Configuration

The project uses xcconfig-based settings under [`Config`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Config). In particular, the app expects a `GOOGLE_MAPS_API_KEY` build setting for map-related functionality.

If you are setting the project up on a new machine, verify the values in:

- [`Config/Debug.xcconfig`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Config/Debug.xcconfig)
- [`Config/Release.xcconfig`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Config/Release.xcconfig)

## Permissions and Capabilities

Vroom currently requests and uses:

- when-in-use location
- always location access
- motion activity access
- notifications
- background location updates

These permissions support route capture, automatic drive detection, session continuity, and user-facing trip updates.

## Testing

The repository includes both unit and UI tests.

Run the full suite from Xcode or use `xcodebuild`, for example:

```bash
xcodebuild test \
  -scheme Vroom \
  -project Vroom.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Test coverage currently focuses on:

- trip detection rules
- drive tracking service behavior
- analysis logic such as scoring, trap extraction, and insights
- key UI flows such as starting and stopping a drive

## Current Boundaries and Known Gaps

The app is already functional, but several production-facing integrations remain intentionally scoped behind abstractions:

- convoy transport is currently unavailable or preview-only
- sync is wired through a no-op engine
- voice chat remains a placeholder service
- identity is local-first
- some premium-adjacent features are staged behind the subscription and entitlement layer

Those gaps are implementation gaps, not architecture gaps. The repository already contains the interfaces and composition points needed to replace placeholders with production services.

## Documentation

Additional handoff and implementation notes live in [`Docs/README.md`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Docs/README.md) and other files under [`Docs`](/Users/yehosuahercules/Desktop/Misc./Vroom/Vroom/Docs).

## Repository Status

This codebase is designed as a maintainable application foundation for Vroom rather than a single-demo build. The current implementation already supports meaningful local drive tracking workflows while leaving clear seams for future backend sync, convoy networking, and expanded premium functionality.
