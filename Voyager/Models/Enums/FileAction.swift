//
//  FileAction.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

enum FileAction: Hashable, CaseIterable {
    case open
    case openWith
    case openInTerminal
    case quickLook
    case cut
    case copy
    case paste
    case duplicate
    case rename
    case moveToTrash
    case compress
    case pin
    case unpin
    case copyPath
    case showInFinder
    case newFolder
    case reload

    // groups are separated by dividers; no items means the click landed on empty space
    static func groups(for items: [FileItem], isPinned: (URL) -> Bool, canPaste: Bool) -> [[FileAction]] {
        guard !items.isEmpty else {
            return [
                [.newFolder] + (canPaste ? [.paste] : []),
                [.openInTerminal, .copyPath, .showInFinder],
                [.reload],
            ]
        }

        let allFolders = items.allSatisfy(\.opensAsFolder)
        let allFiles = items.allSatisfy { !$0.opensAsFolder }
        let single = items.count == 1
        let pasteTarget = single && allFolders && canPaste

        var opening: [FileAction] = [.open]

        if allFiles {
            opening.append(.openWith)
        }

        if single && allFolders {
            opening.append(.openInTerminal)
        }

        opening.append(.quickLook)

        let clipboard: [FileAction] = [.cut, .copy] + (pasteTarget ? [.paste] : [])
        let editing: [FileAction] = [.duplicate] + (single ? [.rename] : []) + [.compress, .moveToTrash]

        var other: [FileAction] = []

        if allFolders {
            other.append(items.allSatisfy { isPinned($0.url) } ? .unpin : .pin)
        }

        other += [.copyPath, .showInFinder]

        return [opening, clipboard, editing, other]
    }

    var symbol: String {
        switch self {
        case .open: "arrow.up.forward.app"
        case .openWith: "rectangle.stack"
        case .openInTerminal: "terminal"
        case .quickLook: "eye"
        case .cut: "scissors"
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .duplicate: "plus.square.on.square"
        case .rename: "character.cursor.ibeam"
        case .moveToTrash: "trash"
        case .compress: "archivebox"
        case .pin: "pin"
        case .unpin: "pin.slash"
        case .copyPath: "link"
        case .showInFinder: "macwindow"
        case .newFolder: "folder.badge.plus"
        case .reload: "arrow.clockwise"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .open: KeyboardShortcut(.downArrow)
        case .quickLook: KeyboardShortcut("y")
        case .cut: KeyboardShortcut("x")
        case .copy: KeyboardShortcut("c")
        case .paste: KeyboardShortcut("v")
        case .duplicate: KeyboardShortcut("d")
        case .moveToTrash: KeyboardShortcut(.delete)
        case .pin, .unpin: KeyboardShortcut("t", modifiers: [.command, .control])
        case .copyPath: KeyboardShortcut("c", modifiers: [.command, .option])
        case .newFolder: KeyboardShortcut("n", modifiers: [.command, .shift])
        case .reload: KeyboardShortcut("r")
        case .rename: KeyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!)), modifiers: [])
        case .openWith, .openInTerminal, .compress, .showInFinder: nil
        }
    }
}
