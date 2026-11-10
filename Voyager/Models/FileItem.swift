//
//  FileItem.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let size: Int64?
    let modified: Date?
    let kind: String
    let type: UTType?
    let isDirectory: Bool
    let isPackage: Bool

    var id: URL { url }

    var opensAsFolder: Bool {
        isDirectory && !isPackage
    }
}

extension FileItem {
    static let defaultOrder = [KeyPathComparator(\FileItem.name, comparator: .localizedStandard)]

    static func arrange(_ items: [FileItem], by order: [KeyPathComparator<FileItem>]) -> [FileItem] {
        items.sorted { lhs, rhs in
            if lhs.opensAsFolder != rhs.opensAsFolder {
                return lhs.opensAsFolder
            }

            for comparator in order {
                switch comparator.compare(lhs, rhs) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
