//
//  ImageMetadataTag.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// The tags of the metadata of a photo file, by the path ImageIO names a tag with: its prefix and its name, such as
/// `exif:FNumber`.
enum ImageMetadataTag {

    /// The tags of the metadata, none for a photo without metadata.
    static func tags(of metadata: CGImageMetadata?) -> [CGImageMetadataTag] {
        metadata.flatMap { CGImageMetadataCopyTags($0) as? [CGImageMetadataTag] } ?? []
    }

    /// The path of a tag, nil for a tag without a prefix or a name.
    static func path(of tag: CGImageMetadataTag) -> String? {
        guard let prefix = CGImageMetadataTagCopyPrefix(tag), let name = CGImageMetadataTagCopyName(tag) else {
            return nil
        }
        return "\(prefix):\(name)"
    }

    /// Sets the tag at its own path in the metadata, its namespace known to the metadata first. False when the tag has
    /// no path or ImageIO cannot set it.
    static func set(_ tag: CGImageMetadataTag, in metadata: CGMutableImageMetadata) -> Bool {
        guard let path = path(of: tag),
              let namespace = CGImageMetadataTagCopyNamespace(tag),
              let prefix = CGImageMetadataTagCopyPrefix(tag),
              CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace, prefix, nil) else {
            return false
        }
        return CGImageMetadataSetTagWithPath(metadata, nil, path as CFString, tag)
    }
}
