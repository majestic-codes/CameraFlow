//
//  FlowInterfaceOrientations.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// An Info.plist value that names no interface orientation.
struct UnknownInterfaceOrientation: Error, Equatable {
    let name: String
}

/// The quarters the flow's interface stands in. The flow keeps it portrait, as the stock camera does, in an app that
/// has portrait. An app without portrait gets its own quarters: the system shows no screen in a quarter the app does
/// not allow.
struct FlowInterfaceOrientations: Equatable, Sendable {
    /// The quarters, in the order the app lists them.
    let quarters: [InterfaceQuarter]
    /// The quarter the flow is presented in: portrait, or the first the app lists.
    let preferred: InterfaceQuarter

    /// The quarters for an app that allows `appQuarters`. An app that lists none has the system's default, which
    /// holds portrait.
    init(appQuarters: [InterfaceQuarter]) {
        guard let first = appQuarters.first, !appQuarters.contains(.portrait) else {
            quarters = [.portrait]
            preferred = .portrait
            return
        }
        quarters = appQuarters
        preferred = first
    }

    /// The quarters an Info.plist value lists, in its order.
    static func quarters(named names: [String]) throws(UnknownInterfaceOrientation) -> [InterfaceQuarter] {
        try names.map { name throws(UnknownInterfaceOrientation) in
            guard let quarter = InterfaceQuarter(rawValue: name) else {
                throw UnknownInterfaceOrientation(name: name)
            }
            return quarter
        }
    }
}
