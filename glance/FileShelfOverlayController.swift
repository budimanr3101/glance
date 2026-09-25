//
//  FileShelfOverlayController.swift
//  glance
//
//  Standalone visual shell for the Finder file-shelf experiment. It deliberately
//  does not share the face-unlock state machine yet, so the experiment cannot
//  interfere with lock-screen authentication.
//

import AppKit
import SwiftUI

@MainActor
final class FileShelfOverlayController {
    static let shared = FileShelfOverlayController()

    private let panel: NSPanel
    private var dismissTask: Task<Void, Never>?

    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 86),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
    }

    func present(_ presentation: FileShelfPresentation) {
        guard NotchOverlayController.shared.phase != .onboarding,
              !NotchOverlayController.shared.isArmed else {
            return
        }

        dismissTask?.cancel()

        let root = FileShelfExperimentView(presentation: presentation)
        panel.contentView = NSHostingView(rootView: root)
        positionPanel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let screen = NotchGeometry.preferredScreen() ?? NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct FileShelfExperimentView: View {
    let presentation: FileShelfPresentation
    @State private var appeared = false

    private var title: String {
        switch presentation.state {
        case .staged:
            return presentation.itemCount == 1 ? "File staged" : "\(presentation.itemCount) files staged"
        case .pasteTarget:
            return presentation.itemCount == 1 ? "Ready to move" : "\(presentation.itemCount) files ready"
        }
    }

    private var subtitle: String {
        switch presentation.state {
        case .staged:
            return presentation.fileNames.first ?? ""
        case .pasteTarget(let destination):
            return "Destination: \(destination)"
        }
    }

    private var symbol: String {
        switch presentation.state {
        case .staged: return presentation.itemCount > 1 ? "doc.on.doc.fill" : "doc.fill"
        case .pasteTarget: return "folder.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Image(systemName: presentation.state.isDestination ? "arrow.down.right" : "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(width: 330, height: 86)
        .scaleEffect(appeared ? 1 : 0.72, anchor: .top)
        .opacity(appeared ? 1 : 0)
        .blur(radius: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }
}

private extension FileShelfPresentation.State {
    var isDestination: Bool {
        if case .pasteTarget = self { return true }
        return false
    }
}
