//
//  FileHistory.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Observation

enum FileStep: Sendable {
    case move([Relocation])
    case trash([URL], permanently: Bool)
}

struct Relocation: Sendable {
    let from: URL
    let to: URL
}

struct HistoryEntry {
    let step: FileStep
    let name: String
}

struct HistoryFailure {
    let title: String
    let message: String
}

struct PendingDelete {
    let isUndo: Bool
    let name: String
}

@MainActor
@Observable
final class FileHistory {
    static let shared = FileHistory()
    static let limit = 100

    private(set) var undoStack: [HistoryEntry] = []
    private(set) var redoStack: [HistoryEntry] = []
    private(set) var isBusy = false
    private(set) var revision = 0
    var failure: HistoryFailure?
    var pendingDelete: PendingDelete?

    var undoTitle: String { undoStack.last.map { "Undo \($0.name)" } ?? "Undo" }
    var redoTitle: String { redoStack.last.map { "Redo \($0.name)" } ?? "Redo" }

    private init() {}

    static func name(_ verb: String, count: Int) -> String {
        count == 1 ? verb : "\(verb) \(count) Items"
    }

    func record(_ step: FileStep, named name: String) {
        undoStack.append(HistoryEntry(step: step, name: name))

        if undoStack.count > Self.limit {
            undoStack.removeFirst()
        }

        redoStack.removeAll()
    }

    func undo() async {
        await run(isUndo: true)
    }

    func redo() async {
        await run(isUndo: false)
    }

    func deletePermanently(_ pending: PendingDelete) async {
        await run(isUndo: pending.isUndo, permanently: true)
    }

    private func run(isUndo: Bool, permanently: Bool = false) async {
        guard !isBusy, let entry = isUndo ? undoStack.last : redoStack.last else { return }

        isBusy = true
        defer { isBusy = false }

        var step = entry.step

        if permanently, case .trash(let urls, _) = step {
            step = .trash(urls, permanently: true)
        }

        do {
            let inverse = try await Self.apply(step)

            if isUndo {
                undoStack.removeLast()
            } else {
                redoStack.removeLast()
            }

            if let inverse {
                let reversed = HistoryEntry(step: inverse, name: entry.name)

                if isUndo {
                    redoStack.append(reversed)
                } else {
                    undoStack.append(reversed)
                }
            }

            revision += 1
        } catch HistoryError.noTrash {
            pendingDelete = PendingDelete(isUndo: isUndo, name: entry.name)
        } catch {
            failure = HistoryFailure(title: "\(isUndo ? "Undo" : "Redo") \(entry.name) could not be completed", message: error.localizedDescription)
        }
    }

    @concurrent
    private static func apply(_ step: FileStep) async throws -> FileStep? {
        let manager = FileManager.default

        switch step {
        case .move(let moves):
            try check(moves)

            var done: [Relocation] = []

            do {
                for move in moves {
                    try manager.moveItem(at: move.from, to: move.to)
                    done.append(move)
                }
            } catch {
                for move in done.reversed() {
                    try? manager.moveItem(at: move.to, to: move.from)
                }

                throw error
            }

            return .move(moves.reversed().map { Relocation(from: $0.to, to: $0.from) })
        case .trash(let urls, let permanently):
            try check(urls.map { Relocation(from: $0, to: $0) }, destinations: false)

            if permanently {
                for url in urls {
                    try manager.removeItem(at: url)
                }

                return nil
            }

            var done: [Relocation] = []

            do {
                for url in urls {
                    var landed: NSURL?
                    try manager.trashItem(at: url, resultingItemURL: &landed)
                    done.append(Relocation(from: (landed as URL?) ?? url, to: url))
                }
            } catch {
                for move in done.reversed() {
                    try? manager.moveItem(at: move.from, to: move.to)
                }

                // 3328 means the volume has no trash, as on smb shares
                if (error as? CocoaError)?.code.rawValue == 3328 {
                    throw HistoryError.noTrash
                }

                throw error
            }

            return .move(done)
        }
    }

    // every item is checked before anything moves, so a blocked step changes nothing
    private nonisolated static func check(_ moves: [Relocation], destinations: Bool = true) throws {
        let manager = FileManager.default
        var problems: [String] = []

        for move in moves {
            let name = "\u{201C}\(move.from.lastPathComponent)\u{201D}"
            let source = move.from.deletingLastPathComponent().lastPathComponent

            guard manager.fileExists(atPath: move.from.path(percentEncoded: false)) else {
                problems.append("\(name) is no longer in \(source).")
                continue
            }

            guard destinations else { continue }

            let folder = move.to.deletingLastPathComponent()
            let target = move.to.path(percentEncoded: false)

            // a case-only rename points at the same item on a case-insensitive disk
            let sameItem = target.lowercased() == move.from.path(percentEncoded: false).lowercased()

            if !manager.fileExists(atPath: folder.path(percentEncoded: false)) {
                problems.append("\u{201C}\(folder.lastPathComponent)\u{201D} no longer exists.")
            } else if !sameItem, manager.fileExists(atPath: target) {
                problems.append("An item named \u{201C}\(move.to.lastPathComponent)\u{201D} already exists in \(folder.lastPathComponent).")
            }
        }

        guard problems.isEmpty else { throw HistoryError.blocked(problems) }
    }
}

enum HistoryError: LocalizedError {
    case blocked([String])
    case noTrash

    var errorDescription: String? {
        switch self {
        case .blocked(let problems):
            let shown = problems.prefix(3).joined(separator: "\n")

            return problems.count > 3 ? "\(shown)\nAnd \(problems.count - 3) more." : shown
        case .noTrash:
            return "The share has no Trash."
        }
    }
}
