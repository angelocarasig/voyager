//
//  RenameField.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct RenameField: View {
    let item: FileItem
    let model: BrowserViewModel

    @State private var text = ""
    @State private var selection: TextSelection?
    @State private var isFinished = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Name", text: $text, selection: $selection)
            .labelsHidden()
            .textFieldStyle(.plain)
            .font(SettingsStore.shared.settings.font(scale: 12 / 13))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.Mocha.base, in: .rect(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.userAccent))
            .focused($isFocused)
            .onAppear(perform: start)
            .onSubmit(finish)
            .onExitCommand(perform: cancel)
            .onChange(of: isFocused) {
                if !isFocused {
                    finish()
                }
            }
    }

    private func start() {
        text = item.displayName(showingExtension: SettingsStore.shared.settings.view.showExtensions)

        let stem = BrowserViewModel.renameExtension(of: text, isFolder: item.opensAsFolder).isEmpty
            ? text
            : (text as NSString).deletingPathExtension

        selection = TextSelection(range: text.startIndex..<text.index(text.startIndex, offsetBy: stem.count))
        isFocused = true
    }

    private func finish() {
        guard !isFinished else { return }

        isFinished = true
        Task { await model.commitRename(item, to: text) }
    }

    private func cancel() {
        isFinished = true
        model.renaming = nil
    }
}
