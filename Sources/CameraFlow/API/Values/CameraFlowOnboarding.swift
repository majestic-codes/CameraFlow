//
//  CameraFlowOnboarding.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Whether the flow introduces itself before the system asks for an access it needs.
///
/// The introduction is a step on the camera's black for each access the user has not answered yet. A step says what
/// the access is for and has one button, Continue, which always brings the system's request: a user who does not
/// want to give the access refuses it in the system's alert, as Apple's guidelines for screens before a request ask.
/// The steps come in this order:
///
/// 1. The camera, while it has not been asked for: what the flow is for. A camera the user refuses shows so in the
///    viewfinder, with a button to the app's page of Settings, and the flow stays open: the user leaves it with the
///    cross or adds photos from the library where the flow has it.
/// 2. The location, where the photos record it and the flow asks for it (``CameraFlowPhotoLocation/automatic``) and
///    when-in-use access has not been asked for: what the location is for. A refused location changes nothing else:
///    the photos go without a location. It follows a granted camera, and comes alone in a flow whose camera was
///    granted before. A camera that is refused gets no location step.
/// 3. The photo library, in a flow that opens with saving to the library on
///    (``CameraFlowConfiguration/photoLibrarySaving``, with the user's stored or remembered choice where the user may
///    switch it) and whose library has not been asked for: the access the save needs. A refused library turns off the
///    saving the user may switch, and the flow goes on to the camera. It follows a granted camera, whether it was
///    granted in this introduction or before, and the location step where that is due. A camera that is refused gets
///    no library step. A flow that opens with saving off asks for the library when the user switches saving on.
///
/// The camera starts behind the steps that follow its own. While a step is on screen, nothing else in the flow
/// brings a system request. The picker of the photo library needs no access, so it is never asked for. The text of
/// a step follows Dynamic Type, and a step taller than the screen scrolls above its Continue button.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowOnboarding: Sendable, Hashable {
    /// The introduction is shown for every access above the user has not answered yet. Once each has an answer,
    /// granted, denied or restricted, the flow opens without it.
    case automatic
    /// No introduction: the system asks for the camera as soon as the flow opens, for the location right after the
    /// camera is granted where the flow asks for it, and for the photo library when a save first needs it.
    case off
}
