# Project rules

Read `AGENTS.md` first and follow it: lint, code style and the project knowledge base live there, with the commands
that build, test and document the package.

- `swiftlint lint --strict` from the repository root must pass, with SwiftLint 0.63.2, the version CI runs.
- `.swiftlint.yml` (`file_header`) requires this header on every Swift file, with the real file name and date:

  ```swift
  //
  //  FileName.swift
  //  CameraFlow
  //
  //  Created by Yevhenii Kalashnikov on DD.MM.YYYY.
  //  Copyright © YYYY Yevhenii Kalashnikov.
  //
  ```

- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`). XCTest is for the UI tests in
  `Example/CameraFlowExampleUITests` only.
- No force unwrap (`!`) and no `try?` outside the one exception in `AGENTS.md`, best-effort cleanup in a `deinit`:
  handle every error explicitly.
- The camera is a device capability. Code that talks to `AVFoundation` sits behind a protocol, so the logic above it is
  tested with a fake session: no test may need a real camera, and none may skip itself when there is none.
- The public API is documented with DocC symbol links, and the documentation builds without a warning: see the
  catalog and the source stability rule in `AGENTS.md`.

## Building and testing

Build and test the package on macOS first: `swift build` and `swift test` from the repository root. For the iOS
targets use the `xcodebuild` commands in `AGENTS.md`. Never pass `-allowProvisioningUpdates`.

## Pull requests

A pull request body has these parts, in English:

1. **What changed**: the change and why, in a few lines.
2. **How it was checked**: commands and what they showed, including what was not checked.
3. **Screenshots**, for a visible change, with the screen, the state and what each image shows.

No binaries in the branch: screenshots and recordings are never committed. No AI footers or co-author lines.
