import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class FileShelfOverlayController {
    static let shared = FileShelfOverlayController()

    private(set) var presentation: FileShelfPresentation?
    private(set) var geometry: NotchGeometry = .forMainScreen()
    private(set) var isVisible = false

    private let windowController = NotchWindowController()
    private var dismissTask: Task<Void, Never>?

    private init() {
        windowController.contentView = NSHostingView(rootView: FileShelfOverlayView(controller: self))
    }

    func present(_ value: FileShelfPresentation) {
        dismissTask?.cancel()
        presentation = value
        geometry = windowController.currentGeometry
        isVisible = true
        windowController.show()
        windowController.setInteractive(false)

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard let self, !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isVisible = false
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, !self.isVisible else { return }
            self.presentation = nil
            self.windowController.hide()
        }
    }
}
