//
//  PathBar.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct PathBar: View {
    @Bindable var model: BrowserViewModel

    @State private var text = ""
    @State private var notFound = false
    @State private var cursor: TextSelection?
    @FocusState private var fieldFocused: Bool

    private let visibleCrumbs = 5

    var body: some View {
        HStack(spacing: 6) {
            Button("Go to Folder", systemImage: "paperplane") {
                if model.isEditingPath {
                    submit()
                } else {
                    model.isEditingPath = true
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.flat(isOn: model.isEditingPath))

            if model.isEditingPath {
                field
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .leading)))
            } else {
                crumbs
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: model.isEditingPath)
    }

    private var field: some View {
        TextField("Folder path", text: $text, selection: $cursor)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .focused($fieldFocused)
            .frame(minWidth: 280, idealWidth: 420, minHeight: 30)
            .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15)))
            .overlay(alignment: .trailing) {
                if notFound {
                    Text("Folder not found")
                        .font(SettingsStore.shared.settings.font(scale: 10 / 13))
                        .foregroundStyle(.red)
                        .padding(.trailing, 8)
                }
            }
            .onAppear {
                let path = model.current.folderKey
                text = path == "/" ? path : path + "/"
                notFound = false
                fieldFocused = true
            }
            .onKeyPress(.tab) {
                complete()
                return .handled
            }
            .onChange(of: text) { notFound = false }
            // focusing selects all, so the cursor moves once focus has landed
            .onChange(of: fieldFocused) { _, focused in
                if focused {
                    moveCursorToEnd()
                } else {
                    model.isEditingPath = false
                }
            }
            .onSubmit(submit)
            .onExitCommand { model.isEditingPath = false }
    }

    private var crumbs: some View {
        let trail = breadcrumbs(for: model.current)
        let hidden = max(0, trail.count - visibleCrumbs)

        return HStack(spacing: 2) {
            if hidden > 0 {
                crumb(trail[0])
                separator
                Menu("…") {
                    ForEach(trail[1...hidden], id: \.self) { url in
                        Button(url.lastPathComponent) { go(to: url) }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.flat)
                .menuIndicator(.hidden)
                .fixedSize()
                separator
            }

            ForEach(Array(trail.dropFirst(hidden > 0 ? hidden + 1 : 0).enumerated()), id: \.element) { index, url in
                if index > 0 {
                    separator
                }

                crumb(url)
            }
        }
        .lineLimit(1)
    }

    private var separator: some View {
        Image(systemName: "chevron.compact.right")
            .foregroundStyle(.tertiary)
    }

    private func crumb(_ url: URL) -> some View {
        let isCurrent = url.folderKey == model.current.folderKey

        return Button {
            go(to: url)
        } label: {
            if url.folderKey == "/" {
                Image(systemName: "internaldrive")
            } else {
                Text(url.lastPathComponent)
                    .fontWeight(isCurrent ? .semibold : .regular)
            }
        }
        .buttonStyle(.flat)
        .foregroundStyle(isCurrent ? .primary : .secondary)
    }

    private func go(to url: URL) {
        Task { await model.navigate(to: url) }
    }

    private func submit() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        if let folder = resolvePath(text, home: home) {
            model.isEditingPath = false
            go(to: folder)
        } else if let file = resolveFile(text, home: home) {
            model.isEditingPath = false
            Task { await model.reveal([file]) }
        } else {
            notFound = true
            NSSound.beep()
        }
    }

    // listing a nas folder can stall, so completion runs off the main actor
    private func complete() {
        let typed = text

        Task {
            guard let completed = await Self.completion(for: typed), text == typed else {
                NSSound.beep()
                return
            }

            text = completed
            moveCursorToEnd()
        }
    }

    @concurrent
    private static func completion(for input: String) async -> String? {
        completePath(input, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    private func moveCursorToEnd() {
        cursor = TextSelection(insertionPoint: text.endIndex)
    }
}
