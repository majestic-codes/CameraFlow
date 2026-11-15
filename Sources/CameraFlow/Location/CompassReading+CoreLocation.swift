//
//  CompassReading+CoreLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

extension CompassReading {

    /// Whether an error of Core Location's manager ends the reading a photo takes: a heading failure says the compass
    /// cannot tell the direction now. An error of the location leaves the reading as it is.
    static func isEnded(by error: any Error) -> Bool {
        guard let error = error as? CLError else { return false }
        return error.code == .headingFailure
    }
}
