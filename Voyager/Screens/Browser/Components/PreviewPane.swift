//
//  PreviewPane.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Quartz
import SwiftUI

struct PreviewPane: View {
    let model: BrowserViewModel

    var body: some View {
        let items = model.selectedItems

        Group {
            if items.count == 1, let item = items.first, !item.opensAsFolder {
                QuickLook(url: item.url)
            } else if items.count == 1, let item = items.first {
                message {
                    FileIcon(item: item, size: 96)
                    Text(item.displayName(showingExtension: SettingsStore.shared.settings.view.showExtensions))
                }
            } else if items.isEmpty {
                message { Text("Select a file to preview it.") }
            } else {
                message { Text("\(items.count) items selected") }
            }
        }
        .font(SettingsStore.shared.settings.font())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
        }
        .foregroundStyle(Color.secondary)
        .multilineTextAlignment(.center)
        .padding()
    }
}

private struct QuickLook: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.previewItem = url as NSURL

        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? URL) != url {
            view.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
        view.previewItem = nil
        view.close()
    }
}
