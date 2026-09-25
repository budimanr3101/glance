//
//  FileShelfController.swift
//  glance
//
//  Experimental Finder -> notch file shelf.
//  V0 is intentionally non-destructive: Cmd+X stages Finder selection in memory,
//  Cmd+Shift+V previews the Finder destination, but no file is moved yet.
//

import AppKit
import ApplicationServices
import Foundation

struct FileShelfPresentation: Equatable {
    enum State: Equatable {
        case staged
        case pasteTarget(String)
    }

    let fileNames: [String]
    let state: State

    var itemCount: Int { fileNames.count }
}

@MainActor
final class FileShelfController {
    private var globalKeyMonitor: Any?
    private(set) var stagedFiles: [URL] = []

    func start() {
        guard globalKeyMonitor == nil else { return }

        if !AXIsProcessTrusted() {
            print("[FileShelf] Accessibility is not granted yet; Finder shortcuts will start working after Glance is trusted.")
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let characters = event.charactersIgnoringModifiers?.lowercased()
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isRepeat = event.isARepeat

            Task { @MainActor [weak self] in
                self?.handleShortcut(
                    characters: characters,
                    modifiers: modifiers,
                    isRepeat: isRepeat
                )
            }
        }

        print("[FileShelf] Experimental monitor started")
    }

    func stop() {
        guard let globalKeyMonitor else { return }
        NSEvent.removeMonitor(globalKeyMonitor)
        self.globalKeyMonitor = nil
    }

    private func handleShortcut(
        characters: String?,
        modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool
    ) {
        guard !isRepeat else { return }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }
        guard modifiers.contains(.command) else { return }
        guard !modifiers.contains(.option), !modifiers.contains(.control) else { return }

        switch characters {
        case "x" where !modifiers.contains(.shift):
            stageFinderSelection()
        case "v" where modifiers.contains(.shift):
            previewPasteDestination()
        default:
            break
        }
    }

    private func stageFinderSelection() {
        guard !NotchOverlayController.shared.isArmed,
              NotchOverlayController.shared.phase != .onboarding else {
            return
        }

        guard let paths = finderSelectionPaths(), !paths.isEmpty else {
            print("[FileShelf] Cmd+X detected, but Finder selection was empty/unavailable")
            return
        }

        let urls = paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !urls.isEmpty else { return }
        stagedFiles = urls

        FileShelfOverlayController.shared.present(
            FileShelfPresentation(
                fileNames: urls.map(\.lastPathComponent),
                state: .staged
            )
        )

        print("[FileShelf] Staged \(urls.count) item(s): \(urls.map(\.path))")
    }

    private func previewPasteDestination() {
        guard !stagedFiles.isEmpty else { return }
        guard !NotchOverlayController.shared.isArmed,
              NotchOverlayController.shared.phase != .onboarding else {
            return
        }

        guard let destinationPath = finderDestinationPath() else {
            print("[FileShelf] Cmd+Shift+V detected, but Finder destination was unavailable")
            return
        }

        let destinationURL = URL(fileURLWithPath: destinationPath).standardizedFileURL
        let destinationName = destinationURL.lastPathComponent.isEmpty
            ? destinationURL.path
            : destinationURL.lastPathComponent

        FileShelfOverlayController.shared.present(
            FileShelfPresentation(
                fileNames: stagedFiles.map(\.lastPathComponent),
                state: .pasteTarget(destinationName)
            )
        )

        // EXPERIMENT SAFETY: do not move/copy/delete anything yet.
        print("[FileShelf] EXPERIMENT ONLY: would move \(stagedFiles.count) item(s) to \(destinationURL.path)")
    }

    private func finderSelectionPaths() -> [String]? {
        let source = #"""
        tell application "Finder"
            set selectedItems to selection
            if (count of selectedItems) is 0 then return ""
            set output to ""
            repeat with selectedItem in selectedItems
                set output to output & POSIX path of (selectedItem as alias) & linefeed
            end repeat
            return output
        end tell
        """#

        guard let value = runAppleScript(source) else { return nil }
        return value
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func finderDestinationPath() -> String? {
        let source = #"""
        tell application "Finder"
            if (count of Finder windows) > 0 then
                set destinationFolder to target of front Finder window as alias
            else
                set destinationFolder to desktop as alias
            end if
            return POSIX path of destinationFolder
        end tell
        """#

        guard let value = runAppleScript(source)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            print("[FileShelf] Finder AppleScript error: \(error)")
            return nil
        }
        return result.stringValue
    }
}
