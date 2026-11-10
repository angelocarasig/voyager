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

    private var selected: Binding<String?> {
        Binding {
            current.folderKey
        } set: { key in
            guard let key, key != current.folderKey else { return }

            navigate(URL(filePath: key, directoryHint: .isDirectory))
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
            }
        }
        .listStyle(.sidebar)
    }

    private func symbol(for url: URL, in section: SidebarSection) -> String {
        switch section.title {
        case "NAS":
            return "externaldrive.connected.to.line.below"
        case "Volumes":
            return "externaldrive"
        default:
            break
        }

        switch url.lastPathComponent {
        case "Desktop": return "menubar.dock.rectangle"
        case "Documents": return "doc"
        case "Downloads": return "arrow.down.circle"
        default: return "house"
        }
    }
}
