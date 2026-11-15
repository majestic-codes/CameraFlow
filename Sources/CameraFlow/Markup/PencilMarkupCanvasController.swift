//
//  PencilMarkupCanvasController.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PencilKit
import UIKit

/// The PencilKit canvas over a photo: strokes, drawn with the system tool picker. Its view is transparent but for
/// the ink.
///
/// Apple Pencil draws, and a finger draws as the system's Apple Pencil setting allows. The canvas is empty when it
/// has no strokes.
final class PencilMarkupCanvasController: UIViewController, EmbeddableMarkupCanvas, PKCanvasViewDelegate {
    private let container = MarkupCanvasView()
    private let canvas = PKCanvasView()
    private let edit: MarkupEdit<PKDrawing>
    private lazy var tools = MarkupCanvasTools { [weak self] in
        self?.changeHandler()
    }
    private var changeHandler: @MainActor () -> Void = {}

    init(drawing: MarkupDrawing?) throws {
        edit = try MarkupEdit(drawing)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var viewController: UIViewController {
        self
    }

    var canUndo: Bool {
        tools.canUndo
    }

    var canRedo: Bool {
        tools.canRedo
    }

    var hasChanges: Bool {
        edit.changedDrawing(canvas.drawing) != nil
    }

    func undo() {
        tools.undo()
    }

    func redo() {
        tools.redo()
    }

    func currentDrawing() async throws -> MarkupDrawing? {
        try await edit.currentDrawing(canvas.drawing)
    }

    func setChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        changeHandler = handler
    }

    override func loadView() {
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // PencilKit picks its default ink for the appearance it is shown in, and the flow is dark.
        overrideUserInterfaceStyle = .dark
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .default
        canvas.isScrollEnabled = false
        canvas.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard edit.isOpen == false, view.bounds.isEmpty == false else {
            return
        }
        let canvasSize = view.bounds.size
        canvas.drawing = edit.open(canvasSize: canvasSize)
        container.show(canvas, canvasSize: canvasSize)
        tools.open(canvas)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tools.appear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tools.disappear()
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        changeHandler()
    }
}
#endif
