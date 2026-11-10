//
//  SortField.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

enum SortField: String, CaseIterable, Codable, Identifiable {
    case name, modified, created, kind, size

    var id: Self { self }

    var title: String {
        switch self {
        case .name: "Name"
        case .modified: "Date modified"
        case .created: "Date created"
        case .kind: "Type"
        case .size: "Size"
        }
    }

    func comparator(ascending: Bool) -> KeyPathComparator<FileItem> {
        let order: SortOrder = ascending ? .forward : .reverse

        switch self {
        case .name: return KeyPathComparator(\FileItem.name, comparator: .localizedStandard, order: order)
        case .kind: return KeyPathComparator(\FileItem.kind, comparator: .localizedStandard, order: order)
        case .modified: return KeyPathComparator(\FileItem.modified, order: order)
        case .created: return KeyPathComparator(\FileItem.created, order: order)
        case .size: return KeyPathComparator(\FileItem.size, order: order)
        }
    }

    init?(_ comparator: KeyPathComparator<FileItem>) {
        guard let match = Self.allCases.first(where: { $0.comparator(ascending: true).keyPath == comparator.keyPath }) else { return nil }

        self = match
    }
}
