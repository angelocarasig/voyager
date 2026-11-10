//
//  FileGroup.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

struct FileGroup: Identifiable {
    let id: String
    let title: String
    let items: [FileItem]
}

private let modifiedTitles = [
    "Today", "Yesterday", "Earlier this week", "Last week", "Earlier this month", "Earlier this year", "A long time ago",
]

private let sizeTitles = ["Folders", "Empty", "Tiny", "Small", "Medium", "Large", "Huge", "Gigantic"]

// items keep their incoming order inside each group; empty groups are dropped
func fileGroups(_ items: [FileItem], by field: GroupField, now: Date = .now, calendar: Calendar = .current) -> [FileGroup] {
    guard field != .none else {
        return [FileGroup(id: "", title: "", items: items)]
    }

    let buckets = Dictionary(grouping: items) { bucket(of: $0, by: field, now: now, calendar: calendar) }
    let order: [String]

    switch field {
    case .kind:
        let folder = buckets.keys.filter { key in buckets[key]?.first?.opensAsFolder == true }
        let others = buckets.keys.filter { !folder.contains($0) }

        order = folder.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            + others.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    case .modified:
        order = modifiedTitles
    case .size:
        order = sizeTitles
    case .name:
        order = buckets.keys.sorted { lhs, rhs in
            (rank(lhs), lhs) < (rank(rhs), rhs)
        }
    case .none:
        order = []
    }

    return order.compactMap { title in
        buckets[title].map { FileGroup(id: title, title: title, items: $0) }
    }
}

private func bucket(of item: FileItem, by field: GroupField, now: Date, calendar: Calendar) -> String {
    switch field {
    case .kind:
        return item.kind.isEmpty ? "Unknown" : item.kind
    case .modified:
        return modifiedTitle(item.modified, now: now, calendar: calendar)
    case .size:
        return sizeTitle(item)
    case .name:
        guard let first = item.name.first else { return "#" }

        if first.isLetter {
            return String(first).uppercased()
        }

        return first.isNumber ? "0-9" : "#"
    case .none:
        return ""
    }
}

private func rank(_ title: String) -> Int {
    switch title {
    case "0-9": 1
    case "#": 2
    default: 0
    }
}

private func modifiedTitle(_ date: Date?, now: Date, calendar: Calendar) -> String {
    guard let date else { return modifiedTitles[6] }

    if calendar.isDate(date, inSameDayAs: now) {
        return modifiedTitles[0]
    }

    if calendar.isDateInYesterday(date) {
        return modifiedTitles[1]
    }

    if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
        return modifiedTitles[2]
    }

    if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
       calendar.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear) {
        return modifiedTitles[3]
    }

    if calendar.isDate(date, equalTo: now, toGranularity: .month) {
        return modifiedTitles[4]
    }

    if calendar.isDate(date, equalTo: now, toGranularity: .year) {
        return modifiedTitles[5]
    }

    return modifiedTitles[6]
}

private func sizeTitle(_ item: FileItem) -> String {
    if item.opensAsFolder {
        return sizeTitles[0]
    }

    let kilobyte: Int64 = 1_024
    let megabyte = kilobyte * 1_024
    let gigabyte = megabyte * 1_024
    let size = item.size ?? 0

    switch size {
    case 0: return sizeTitles[1]
    case ..<(16 * kilobyte): return sizeTitles[2]
    case ..<megabyte: return sizeTitles[3]
    case ..<(128 * megabyte): return sizeTitles[4]
    case ..<gigabyte: return sizeTitles[5]
    case ..<(4 * gigabyte): return sizeTitles[6]
    default: return sizeTitles[7]
    }
}
