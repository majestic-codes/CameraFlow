//
//  PaperMarkupCanvasController.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PaperKit
import PencilKit
import UIKit

/// The PaperKit canvas over a photo: strokes drawn with the system tool picker, and text, shapes and stickers
/// inserted from the "+" of the picker.
///
/// PaperKit shows the photo itself under the ink, in the same place as the screen does, so the canvas is whole
/// while the page under it goes back to its fitted size. Apple Pencil draws, and a finger draws as the system's
/// Apple Pencil setting allows and selects otherwise. The canvas is empty when nothing on it renders.
@available(iOS 26, *)
final class PaperMarkupCanvasController: UIViewController, EmbeddableMarkupCanvas {
    private let photo: CGImage
    private let edit: MarkupEdit<PaperMarkup>
    private let container = MarkupCanvasView()
    private let insertMenu = MarkupEditViewController(supportedFeatureSet: PaperMarkupFeatures.supported)
    private let sceneAppearance = DarkSceneAppearance()
    private lazy var tools = MarkupCanvasTools { [weak self] in
        self?.changeHandler()
    }
    /// PaperKit's editor, from the first layout on.
    private var paper: PaperMarkupViewController?
    private var changeHandler: @MainActor () -> Void = {}

    init(photo: CGImage, drawing: MarkupDrawing?) throws {
        self.photo = photo
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
        edit.changedDrawing(paper?.markup) != nil
    }

    func undo() {
        tools.undo()
    }

    func redo() {
        tools.redo()
    }

    func currentDrawing() async throws -> MarkupDrawing? {
        try await edit.currentDrawing(paper?.markup)
    }

    func setChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        changeHandler = handler
    }

    override func loadView() {
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        tools.toolPicker.accessoryItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(showInsertMenu)
        )
        insertMenu.overrideUserInterfaceStyle = .dark
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard edit.isOpen == false, view.bounds.isEmpty == false else {
            return
        }
        let paper = embedPaper(canvasSize: view.bounds.size)
        self.paper = paper
        tools.open(paper)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let scene = view.window?.windowScene {
            sceneAppearance.apply(to: scene)
        }
        tools.appear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneAppearance.restore()
        tools.disappear()
    }

    /// Embeds PaperKit's editor at the size of the canvas, with what the canvas opens with.
    private func embedPaper(canvasSize: CGSize) -> PaperMarkupViewController {
        let markup = edit.open(canvasSize: canvasSize)
        let paper = PaperMarkupViewController(markup: markup, supportedFeatureSet: PaperMarkupFeatures.supported)
        paper.overrideUserInterfaceStyle = .dark
        let photoView = UIImageView(image: UIImage(cgImage: photo))
        photoView.contentMode = .scaleAspectFit
        paper.contentView = photoView
        paper.delegate = self
        addChild(paper)
        paper.view.backgroundColor = .clear
        container.show(paper.view, canvasSize: canvasSize)
        paper.didMove(toParent: self)
        insertMenu.delegate = paper
        return paper
    }

    @objc private func showInsertMenu(_ sender: UIBarButtonItem) {
        insertMenu.modalPresentationStyle = .popover
        insertMenu.popoverPresentationController?.sourceItem = sender
        insertMenu.popoverPresentationController?.delegate = self
        present(insertMenu, animated: true)
    }
}

@available(iOS 26, *)
extension PaperMarkupCanvasController: @MainActor PaperMarkupViewController.Delegate {

    func paperMarkupViewControllerDidChangeMarkup(_ paperMarkupViewController: PaperMarkupViewController) {
        changeHandler()
    }
}

@available(iOS 26, *)
extension PaperMarkupCanvasController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        // Keeps the insert menu a popover on the phone instead of a full-height sheet.
        .none
    }
}
#endif
