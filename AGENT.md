# AGENT.md

## Project Summary

Vroom is a native iOS driving companion built as a single Xcode project with SwiftUI, SwiftData, Core Location/Core Motion, and StoreKit. The app target is `Vroom`, with domain logic and protocols separated from SwiftUI features and infrastructure implementations so new work should extend the existing layers instead of collapsing logic into views.

## Repository Map

- `Vroom/`: app source for the `Vroom` target.
- `Vroom/App`: root scene wiring.
- `Vroom/Core`: dependency composition, environment setup, logging.
- `Vroom/Domain`: models, analysis engines, drive detection, protocols, and service interfaces.
- `Vroom/Features`: SwiftUI screens plus shared presentation components.
- `Vroom/Infrastructure`: SwiftData repositories, sensor adapters, and concrete service implementations.
- `Vroom/Support`: preview and UI-test fixture data.
- `VroomTests/`: unit tests, primarily using the Swift `Testing` framework.
- `VroomUITests/`: UI tests using `XCTest`.
- `Config/`: `Debug.xcconfig` and `Release.xcconfig`.
- `Docs/`: extra project notes; note that `Docs/README.md` still uses the older `RoadTrack` name.
- `Vroom.xcodeproj/`: Xcode project, targets, build settings, and xcconfig wiring.

## Commands

- Setup/open project: `open Vroom.xcodeproj`
- Build for the local simulator: `xcodebuild build -scheme Vroom -project Vroom.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Run the full test suite: `xcodebuild test -scheme Vroom -project Vroom.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Run a targeted unit suite: `xcodebuild test -scheme Vroom -project Vroom.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VroomTests/TripDetectorTests`
- Run a targeted UI test: `xcodebuild test -scheme Vroom -project Vroom.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VroomUITests/VroomUITests/testOnboardingAppearsOnFirstLaunch`

Notes:

- There is no separate package install step in this repo: no SwiftPM package manifest, CocoaPods, or npm tooling is checked in.
- There is no repo-configured linter or formatter command. Use `xcodebuild build` as the practical compile/typecheck validation.
- Verified locally during init: `xcodebuild build ...` on `iPhone 17 Pro` succeeded, a targeted `TripDetectorTests` run passed, and `xcodebuild -showdestinations` lists `iPhone 17 Pro` as an available simulator destination.
- Expect the first simulator-backed `xcodebuild test` run to spend a long time booting and cloning the simulator before test output appears.

## Conventions

- Preserve the current layering:
  - keep app/session orchestration in `Vroom/Features/AppShell/AppStateStore.swift`
  - keep service and repository protocols in `Vroom/Domain`
  - keep concrete implementations in `Vroom/Infrastructure`
  - register new concrete services in `Vroom/Core/AppContainer.swift`
- If you add or change persisted models, update `Vroom/Infrastructure/Persistence/SwiftDataContainerFactory.swift` so the schema stays in sync with the repository layer.
- UI tests depend on launch arguments:
  - `UITestingSeedPreviewData` seeds in-memory preview fixtures
  - `UITestingInMemoryStore` forces a clean in-memory first-launch flow
- Unit tests and UI tests use different frameworks on purpose:
  - `VroomTests` imports `Testing`
  - `VroomUITests` imports `XCTest`
- The Xcode project uses filesystem-synced groups for `Vroom/`, `VroomTests/`, and `VroomUITests/`, so new files under those directories usually appear automatically in the project. Still verify target membership when adding new sources or resources.

## Validation Before Handoff

- Always run `xcodebuild build -scheme Vroom -project Vroom.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` after code changes.
- Run targeted `VroomTests` when changing domain logic, repositories, services, scoring, or drive detection.
- Run relevant `VroomUITests` when changing onboarding, dashboard, history, garage, premium, or convoy flows.
- If you touch persistence, onboarding bootstrap, or test seeding, verify the launch-argument paths still behave correctly.

## Warnings and Guardrails

- `Config/Debug.xcconfig` and `Config/Release.xcconfig` currently contain a literal `GOOGLE_MAPS_API_KEY`. Treat those files as sensitive configuration, and do not casually rotate, expose, or duplicate the key in code or docs.
- Naming is mixed across the repo: the app target, bundle display name, and most source code say `Vroom`, while `Docs/README.md`, `Vroom/RoadTrack.storekit`, and StoreKit product IDs still use `RoadTrack`. Keep naming edits intentional and coordinated.
- If you touch premium or StoreKit flows, keep `Vroom/Info.plist`, `Vroom/RoadTrack.storekit`, and `Vroom/Infrastructure/Services/StoreKitStorefrontService.swift` aligned.
- `Vroom/Vroom.entitlements` includes APNs and CloudKit-related capability entries. Changes there affect signing and runtime capabilities, so validate on-device or in the simulator as appropriate.

## Related Docs

- `README.md`
- `Docs/README.md`
