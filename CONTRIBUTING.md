# Contributing to CameraFlow

Bug reports and pull requests are welcome. This page lists what a pull request needs: the tools, the commands CI
runs, and the rules the code follows.

A security vulnerability is reported privately, as [SECURITY.md](SECURITY.md) describes, never in an issue or a pull
request.

## Requirements

- Xcode 27 or newer. CI builds and tests with Xcode 27.2.
- SwiftLint 0.63.2, the version CI runs.

Apps build the package with Xcode 26.2 or newer and Swift 6.2.3, the Swift tools version of the package, but its unit
tests need Xcode 27: its `swift test` builds with Swift Build, which compiles `Localizable.xcstrings`. Xcode 26's
`swift test` copies the catalog uncompiled, and the test run stops on a precondition: the package bundle has no `.lproj`
folder.

Homebrew installs the newest SwiftLint, which can report what 0.63.2 does not. Install 0.63.2 from its
[release page](https://github.com/realm/SwiftLint/releases/tag/0.63.2): `SwiftLint.pkg`, or the `swiftlint` binary in
`portable_swiftlint.zip`.

## Build, test and lint

From the repository root:

```sh
swift build
swift test
xcodebuild build-for-testing -scheme CameraFlow -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO
swiftlint lint --strict
```

- `swift build` and `swift test` build the package for macOS and run the unit tests there, against a fake camera.
- On macOS the compiler skips the code inside `#if os(iOS)`: the public screens, the views and the device camera.
  `xcodebuild build-for-testing` compiles the whole package and its tests for iOS. It starts no simulator, runs no
  test and needs no signing.
- `swiftlint lint --strict` reports nothing. The rules live in `.swiftlint.yml`, and a change to them needs the
  maintainer's approval.

CI runs these commands on every pull request and on every push to `main`: the first three on macOS with Xcode 27.2,
SwiftLint on Linux in the `ghcr.io/realm/swiftlint:0.63.2` container. A pull request needs CI to pass.

A change to the public API or to its documentation also builds the documentation, the DocC catalog
`Sources/CameraFlow/CameraFlow.docc` with the `///` comments, which fails on a warning, such as a link to a symbol that
does not exist:

```sh
xcodebuild docbuild -scheme CameraFlow -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO OTHER_DOCC_FLAGS=--warnings-as-errors
```

A change to the iOS-only code is worth running on a simulator as well, where the package tests run with parallel
testing off: parallel HEIC encodes hang in the simulator.

```sh
xcodebuild test -scheme CameraFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO
```

The Example app and its UI tests are not built in CI. The UI tests run on a simulator, by hand, one at a time: run
them for a change the user sees. The Development section of [README.md](README.md#development) has their commands and
what they need, such as a simulator in English for `CameraFlowLibraryUITests`.

## Code style and layers

[AGENTS.md](AGENTS.md) describes the layers of the module, which folder may depend on which, where `public` may appear,
and the code style that SwiftLint does not check. Follow it. `Tests/CameraFlowTests/ArchitectureTests.swift` checks
the layer rules on the source text.

## File header

Every Swift file starts with this header, and SwiftLint's `file_header` rule checks it. Copy it as it is, with the
file's own name, the date the file is created and its year:

```swift
//
//  FileName.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on DD.MM.YYYY.
//  Copyright © YYYY Yevhenii Kalashnikov.
//
```

The rule takes no other names, so the header is the same in every file, whoever writes it.

## Tests

- A change in behaviour comes with unit tests.
- The unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`). XCTest is for the UI tests of
  the Example app only.
- A test lives in `Tests/CameraFlowTests`, in the folder named after the layer it tests. Fakes and conveniences only
  tests need go in `Tests/CameraFlowTests/TestSupport`.
- No test needs a real camera, and none skips itself when there is none: the code that talks to `AVFoundation` sits
  behind a protocol, and the tests use a fake camera.

## Texts

A text the user sees lives in `Sources/CameraFlow/Resources/Localizable.xcstrings`, with a translation for every
language of the catalog: English and 36 translations, Latin American Spanish (`es-419`) among them. A text the stock
camera has takes the stock camera's words in each language. The tests fail when a language misses a text.

## Pull requests

- One change per pull request. Say what changed, why, and how you checked it.
- A change apps notice gets an entry in `CHANGELOG.md`, under `## Unreleased`.
- The public API keeps source stability: a 1.x release adds API and never changes or removes any, and adds no case to a
  public enum, except to the three marked `@nonexhaustive`. A new value comes as a new type or property, never as a new
  case. The `@_spi(Testing)` fixtures are outside this promise.

## Before a release

The maintainer runs the checks CI leaves out, from the repository root:

1. The package builds with Xcode 26.2, the oldest Xcode the README names. With that Xcode selected (`xcode-select` or
   `DEVELOPER_DIR`):

   ```sh
   xcodebuild build -scheme CameraFlow -destination 'generic/platform=iOS Simulator' \
     -skipMacroValidation CODE_SIGNING_ALLOWED=NO
   ```

2. The package tests pass on a simulator of the newest iOS, as above, and on one of iOS 18, which has no PaperKit: the
   PencilKit markup runs there, and so do the classes that must not hold a PaperKit value.

   ```sh
   xcodebuild test -scheme CameraFlow -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
     -parallel-testing-enabled NO -skipMacroValidation CODE_SIGNING_ALLOWED=NO
   ```

3. The Example builds, its UI tests pass, and `CameraFlowMarkupUITests` passes on the iOS 18 simulator too.
4. A Release build of the Example links PaperKit weakly, so the app launches on iOS 17 and 18:

   ```sh
   xcodebuild build -project Example/CameraFlowExample.xcodeproj -scheme CameraFlowExample -configuration Release \
     -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData \
     -skipMacroValidation CODE_SIGNING_ALLOWED=NO
   otool -L DerivedData/Build/Products/Release-iphonesimulator/CameraFlowExample.app/CameraFlowExample | grep PaperKit
   ```

   The PaperKit line ends with `weak)`.
5. `CHANGELOG.md` has the version and its date in place of `## Unreleased`, under a new empty `## Unreleased`, and a
   new major version changes `from:` in the README's installation.
6. Private vulnerability reporting is on (**Settings** > **Code security** > **Private vulnerability reporting**), so
   the form `SECURITY.md` sends reports to exists. GitHub leaves it off for a new or newly public repository.
