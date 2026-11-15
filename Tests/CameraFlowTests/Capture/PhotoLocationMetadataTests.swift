//
//  PhotoLocationMetadataTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation
import ImageIO
import Testing
@testable import CameraFlow

@Suite("Photo location metadata")
struct PhotoLocationMetadataTests {

    @Test(
        "Latitude and longitude are written as magnitudes with their hemisphere",
        arguments: [
            (50.45, 30.52, "N", "E"),
            (-33.86, 151.21, "S", "E"),
            (40.71, -74.0, "N", "W"),
            (-22.9, -43.2, "S", "W")
        ]
    )
    func coordinates(latitude: Double, longitude: Double, latitudeRef: String, longitudeRef: String) {
        let location = LocationFixture.location(latitude: latitude, longitude: longitude)
        let gps = PhotoLocationMetadata.gpsDictionary(for: location)
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == abs(latitude))
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == latitudeRef)
        #expect(gps[kCGImagePropertyGPSLongitude] as? Double == abs(longitude))
        #expect(gps[kCGImagePropertyGPSLongitudeRef] as? String == longitudeRef)
    }

    @Test("Altitude is a magnitude with 0 above sea level and 1 below", arguments: [(179.0, 0), (-28.0, 1)])
    func altitude(altitude: Double, reference: Int) {
        let gps = PhotoLocationMetadata.gpsDictionary(for: LocationFixture.location(altitude: altitude))
        #expect(gps[kCGImagePropertyGPSAltitude] as? Double == abs(altitude))
        #expect(gps[kCGImagePropertyGPSAltitudeRef] as? Int == reference)
    }

    @Test("The time stamp and the date stamp are in UTC")
    func timestamp() {
        let gps = PhotoLocationMetadata.gpsDictionary(for: LocationFixture.location())
        #expect(gps[kCGImagePropertyGPSTimeStamp] as? String == "18:20:04.25")
        #expect(gps[kCGImagePropertyGPSDateStamp] as? String == "2026:11:05")
    }

    @Test("Accuracy, speed in kilometres per hour and course from true north are written")
    func motion() {
        let gps = PhotoLocationMetadata.gpsDictionary(for: LocationFixture.location())
        #expect(gps[kCGImagePropertyGPSHPositioningError] as? Double == 5)
        #expect(gps[kCGImagePropertyGPSSpeed] as? Double == 9)
        #expect(gps[kCGImagePropertyGPSSpeedRef] as? String == "K")
        #expect(gps[kCGImagePropertyGPSTrack] as? Double == 271.5)
        #expect(gps[kCGImagePropertyGPSTrackRef] as? String == "T")
    }

    @Test("Values the location reports as invalid are left out")
    func invalidValues() {
        let location = LocationFixture.location(horizontalAccuracy: -1, verticalAccuracy: -1, course: -1, speed: -1)
        let gps = PhotoLocationMetadata.gpsDictionary(for: location)
        let absent = [
            kCGImagePropertyGPSHPositioningError,
            kCGImagePropertyGPSAltitude,
            kCGImagePropertyGPSAltitudeRef,
            kCGImagePropertyGPSSpeed,
            kCGImagePropertyGPSSpeedRef,
            kCGImagePropertyGPSTrack,
            kCGImagePropertyGPSTrackRef
        ]
        #expect(absent.allSatisfy { gps[$0] == nil })
        #expect(gps.count == 6)
    }

    @Test(
        "A movie's ISO 6709 location has signed degrees, the altitude where it is valid, and a closing slash",
        arguments: [
            (50.45, 30.52, 179.0, 3.0, "+50.4500+030.5200+179.000/"),
            (-33.86, 151.21, -28.0, 3.0, "-33.8600+151.2100-028.000/"),
            (40.71, -74.0, 10.0, -1.0, "+40.7100-074.0000/"),
            (-22.900_04, -43.200_06, 1_234.5, 2.0, "-22.9000-043.2001+1234.500/")
        ]
    )
    func iso6709(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        verticalAccuracy: Double,
        expected: String
    ) {
        let location = LocationFixture.location(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            verticalAccuracy: verticalAccuracy
        )
        #expect(PhotoLocationMetadata.iso6709(for: location) == expected)
    }

    @Test("ImageIO writes the dictionary into a file as it is")
    func writtenByImageIO() throws {
        let photo = try DevicePhotoFixture.make()
        let image = try #require(CGImageSourceCreateWithData(photo as CFData, nil))
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil))
        let location = LocationFixture.location(latitude: -33.86, longitude: 151.21)
        let gps = PhotoLocationMetadata.gpsDictionary(for: location)
        let properties = [kCGImagePropertyGPSDictionary: gps] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, image, 0, properties)
        #expect(CGImageDestinationFinalize(destination))
        let written = try DevicePhotoFixture.properties(of: data as Data)
        let writtenGPS = try #require(written[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(writtenGPS[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        #expect(writtenGPS[kCGImagePropertyGPSDateStamp] as? String == "2026:11:05")
        #expect(writtenGPS[kCGImagePropertyGPSSpeedRef] as? String == "K")
    }
}
