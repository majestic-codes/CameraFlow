//
//  TopBarReveal.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Which top bar item a scrolling row brings into view.
enum TopBarReveal {

    /// The last item of `items` that was not among `previousItems`, which is the one the user just changed.
    static func newestItem(in items: [CameraSetting], since previousItems: [CameraSetting]) -> CameraSetting? {
        items.last { !previousItems.contains($0) }
    }
}
