//
//  BrowserSidebar.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct BrowserSidebar: View {
    let sections: [SidebarSection]
    let current: URL
    let navigate: (URL) -> Void
    let drop: ([URL], URL) -> Void

    private let shares = NetworkShares.shared

    private var selected: Binding<String?> {
        Binding {
            current.folderKey
        } set: { key in
            guard let key, key != current.folderKey else { return }

            if let share = shares.share(withID: key) {
                open(share)
            } else {
                navigate(URL(filePath: key, directoryHint: .isDirectory))
            }
        }
    }

    var body: some View {
        List(selection: selected) {
            if !Pins.shared.folders.isEmpty {
                Section("Pinned") {
                    ForEach(Pins.shared.folders, id: \.folderKey) { url in
                        Label(url.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .tag(url.folderKey)
                            .dropDestination(for: URL.self) { urls, _ in
                                drop(urls, url)
                                return true
                            }
                            .contextMenu {
                                Button("Unpin") { Pins.shared.unpin([url]) }
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            }
                    }
                    .onMove(perform: Pins.shared.move)
                }
            }

            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.locations, id: \.folderKey) { url in
                        Label(url.lastPathComponent, systemImage: symbol(for: url, in: section))
                            .lineLimit(1)
                            .tag(url.folderKey)
                            .dropDestination(for: URL.self) { urls, _ in
                                drop(urls, url)
                                return true
                            }
                    }
                }

                if section.title == "Places", !shares.shares.isEmpty {
                    Section("NAS") {
                        ForEach(shares.shares, id: \.self, content: shareRow)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func shareRow(_ share: URL) -> some View {
        let point = shares.mountPoint(of: share)

        return HStack {
            Label(share.lastPathComponent, systemImage: point == nil ? "externaldrive.badge.xmark" : "externaldrive.connected.to.line.below")
                .lineLimit(1)

            Spacer()

            if shares.connecting.contains(share) {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .opacity(point == nil ? 0.5 : 1)
        .tag(point?.folderKey ?? share.absoluteString)
        .dropDestination(for: URL.self) { urls, _ in
            guard let point else { return false }

            drop(urls, point)
            return true
        }
        .contextMenu {
            if let point {
                Button("Eject") { Task { await shares.eject(share) } }
                Button("Reconnect") { Task { await shares.reconnect(share) } }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([point]) }
            } else {
                Button("Connect") { open(share) }
            }
        }
    }

    private func open(_ share: URL) {
        Task {
            if let point = await shares.open(share) {
                navigate(point)
            }
        }
    }

    private func symbol(for url: URL, in section: SidebarSection) -> String {
        if section.title == "Volumes" {
            return "externaldrive"
        }

        switch url.lastPathComponent {
        case "Desktop": return "menubar.dock.rectangle"
        case "Documents": return "doc"
        case "Downloads": return "arrow.down.circle"
        default: return "house"
        }
    }
}
