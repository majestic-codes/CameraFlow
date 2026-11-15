//
//  PhotoLibrarySheet.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PhotosUI
import SwiftUI

/// The system photo picker as a sheet over the flow. It lets the user pick what is left of the set's limit, and
/// the picks reach the set only when the sheet's check mark confirms them.
struct PhotoLibrarySheet: ViewModifier {
    let flow: EmbeddedCameraFlowModel

    @State private var pickedItems: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        @Bindable var flow = flow
        content
            .photosPicker(
                isPresented: $flow.isLibraryPresented,
                selection: $pickedItems,
                maxSelectionCount: flow.librarySelectionLimit,
                matching: .images,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: pickedItems) {
                guard !pickedItems.isEmpty else { return }
                let picks = pickedItems
                pickedItems = []
                Task {
                    await flow.importPicks(picks)
                }
            }
    }
}
#endif
