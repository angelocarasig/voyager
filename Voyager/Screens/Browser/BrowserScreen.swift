//
//  BrowserScreen.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import QuickLook
import SwiftUI

struct BrowserScreen: View {
    @State private var model = BrowserViewModel(start: FileManager.default.homeDirectoryForCurrentUser)
    @State private var sections: [SidebarSection] = []
    @State private var typeAhead = TypeAhead()
    @State private var columns = NavigationSplitViewVisibility.all

    @AppStorage(Preferences.Key.askedForFullDiskAccess) private var askedForFullDiskAccess = false
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            BrowserSidebar(sections: sections, current: model.current) { url in
                Task { await model.navigate(to: url) }
            } drop: { urls, folder in
                Task { await model.drop(urls, into: folder) }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            content
                .toolbar { toolbar }
        }
        .navigationTitle(model.current.lastPathComponent)
        .toolbar(removing: .title)
        .focusedSceneValue(\.browser, model)
        .quickLookPreview($model.previewURL, in: model.selectedItems.map(\.url))
        .onChange(of: model.selection) {
            if model.previewURL != nil {
                model.previewURL = model.selectedItems.first?.url
            }
        }
        .onChange(of: model.view) { model.rearrange() }
        .onChange(of: SettingsStore.shared.settings.view.showHidden) { Task { await model.reload() } }
        // the alert clears its value before a button runs, so the buttons use the value it presented
        .alert(extensionTitle, isPresented: hasExtensionChange, presenting: model.extensionChange) { change in
            Button("Use .\(change.newExtension)") { Task { await model.apply(change, keepingOld: false) } }
            Button("Keep .\(change.oldExtension)", role: .cancel) { Task { await model.apply(change, keepingOld: true) } }
        } message: { _ in
            Text("The file may open in a different app, or stop opening.")
        }
        .onChange(of: FileHistory.shared.revision) { Task { await model.reload() } }
        .alert(FileHistory.shared.failure?.title ?? "", isPresented: hasHistoryFailure, presenting: FileHistory.shared.failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure.message)
        }
        .alert("Delete permanently?", isPresented: hasPendingDelete, presenting: FileHistory.shared.pendingDelete) { pending in
            Button("Delete", role: .destructive) { Task { await FileHistory.shared.deletePermanently(pending) } }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text("This share has no Trash, so \(pending.isUndo ? "undoing" : "redoing") \(pending.name) deletes the items for good.")
        }
        .alert("Action could not be completed", isPresented: hasOperationFailure, presenting: model.operationFailure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
        .sheet(isPresented: needsFullDiskAccess) {
            FullDiskAccessSheet()
        }
        // with several windows open, only the front one shows what another app asked for
        .onChange(of: OpenRequests.shared.pending) { takeOpenRequest() }
        .onChange(of: appearsActive) { takeOpenRequest() }
        .task { await model.reload() }
        .task(id: NetworkShares.shared.revision) { await loadSections() }
        .onChange(of: SettingsStore.shared.settings.shares) { Task { await loadSections() } }
        .alert("Share could not be connected", isPresented: hasShareFailure, presenting: NetworkShares.shared.failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
        .background(ToolbarLock())
        .background(MouseButtons(actions: [
            MouseButtons.back: { _ in
                Task { await model.goBack() }
                return true
            },
            MouseButtons.forward: { _ in
                Task { await model.goForward() }
                return true
            },
        ]))
        .background(ControlScroll { model.zoom(by: $0) })
        .font(SettingsStore.shared.settings.font())
        .windowBackground(SettingsStore.shared.settings)
        .preferredColorScheme(.dark)
        .tint(Color.userAccent)
        .frame(minWidth: 700, minHeight: 400)
    }

    private var hasExtensionChange: Binding<Bool> {
        Binding { model.extensionChange != nil } set: { if !$0 { model.extensionChange = nil } }
    }

    private var extensionTitle: String {
        guard let change = model.extensionChange else { return "" }

        return "Change the extension from .\(change.oldExtension) to .\(change.newExtension)?"
    }

    private var needsFullDiskAccess: Binding<Bool> {
        Binding { !askedForFullDiskAccess && !SystemAccess.shared.hasFullDiskAccess } set: { if !$0 { askedForFullDiskAccess = true } }
    }

    private func takeOpenRequest() {
        guard appearsActive, let urls = OpenRequests.shared.take() else { return }

        Task { await model.reveal(urls) }
    }

    private var hasShareFailure: Binding<Bool> {
        Binding { appearsActive && NetworkShares.shared.failure != nil } set: { if !$0 { NetworkShares.shared.failure = nil } }
    }

    private var hasHistoryFailure: Binding<Bool> {
        Binding { appearsActive && FileHistory.shared.failure != nil } set: { if !$0 { FileHistory.shared.failure = nil } }
    }

    private var hasPendingDelete: Binding<Bool> {
        Binding { appearsActive && FileHistory.shared.pendingDelete != nil } set: { if !$0 { FileHistory.shared.pendingDelete = nil } }
    }

    private var hasOperationFailure: Binding<Bool> {
        Binding { model.operationFailure != nil } set: { if !$0 { model.operationFailure = nil } }
    }

    private var isOpeningFolder: Bool {
        model.isLoading && model.items.isEmpty
    }

    @ViewBuilder
    private var content: some View {
        let view = SettingsStore.shared.settings.view

        if view.previewPane || view.detailsPane {
            HSplitView {
                files

                Group {
                    if view.previewPane {
                        PreviewPane(model: model)
                    } else {
                        DetailsPane(model: model)
                    }
                }
                .frame(minWidth: 220, idealWidth: 300, maxWidth: 500)
            }
        } else {
            files
        }
    }

    private var files: some View {
        Group {
            if let failure = model.failure {
                ContentUnavailableView {
                    Label("Folder could not be opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(failure)
                } actions: {
                    Button("Try Again") { Task { await model.reload() } }
                }
            } else if isOpeningFolder {
                ContentUnavailableView {
                    Label("Loading \u{201C}\(model.current.lastPathComponent)\u{201D}", systemImage: "folder")
                } description: {
                    ProgressView()
                        .controlSize(.small)
                }
                .transition(.opacity)
            } else {
                Group {
                    if model.view.layout == .details {
                        FileTable(model: model)
                    } else {
                        FileGrid(model: model)
                    }
                }
                // laid over the empty view so its context menu and drops keep working
                .overlay {
                    if model.items.isEmpty && !model.isLoading {
                        ContentUnavailableView {
                            Label("Folder is empty", systemImage: "folder")
                        } description: {
                            Text("Drop items here, or right-click to create a folder.")
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .id(model.itemsFolder)
        .transition(.opacity)
        .opacity(model.isSwitching ? 0.5 : 1)
        .allowsHitTesting(!model.isSwitching)
        .animation(.easeInOut(duration: 0.2), value: isOpeningFolder)
        .animation(.easeInOut(duration: 0.2), value: model.itemsFolder)
        .animation(.easeInOut(duration: 0.15), value: model.isSwitching)
        .onKeyPress(phases: .down, action: handle)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 6) {
                Button("Toggle Sidebar", systemImage: "sidebar.left") {
                    withAnimation {
                        columns = columns == .detailOnly ? .all : .detailOnly
                    }
                }

                Button("Back", systemImage: "chevron.left") { Task { await model.goBack() } }
                    .disabled(!model.canGoBack)

                Button("Forward", systemImage: "chevron.right") { Task { await model.goForward() } }
                    .disabled(!model.canGoForward)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.flat)
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                PathBar(model: model)

                if model.isLoading && !isOpeningFolder {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 6) {
                viewMenu
                sortMenu
                groupMenu
            }
            .labelStyle(.iconOnly)
            .menuIndicator(.hidden)
            .buttonStyle(.flat)
            .padding(.trailing, 8)
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private var viewMenu: some View {
        Menu("View", systemImage: model.view.layout.symbol) {
            Picker("View", selection: Binding { model.view.layout } set: { model.setLayout($0) }) {
                ForEach(ViewLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.symbol)
                        .tag(layout)
                        .keyboardShortcut(layout.shortcut)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Menu("Show") {
                showToggle("Compact view", \.compact)
                showToggle("Item check boxes", \.checkBoxes)
                showToggle("File name extensions", \.showExtensions)
                showToggle("Hidden items", \.showHidden)
                showToggle("Preview pane", \.previewPane) { if $0 { SettingsStore.shared.settings.view.detailsPane = false } }
                showToggle("Details pane", \.detailsPane) { if $0 { SettingsStore.shared.settings.view.previewPane = false } }
            }

            Divider()

            Toggle("Remember view for this folder", isOn: $model.remembersView)
        }
    }

    private var sortMenu: some View {
        Menu("Sort", systemImage: "arrow.up.and.down.text.horizontal") {
            Picker("Sort by", selection: Binding { model.view.sort } set: { field in model.updateView { $0.sort = field } }) {
                ForEach(SortField.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)

            Divider()

            Picker("Order", selection: Binding { model.view.ascending } set: { ascending in model.updateView { $0.ascending = ascending } }) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }
            .pickerStyle(.inline)
        }
    }

    private var groupMenu: some View {
        Menu("Group", systemImage: "rectangle.3.group") {
            Picker("Group by", selection: Binding { model.view.group } set: { field in model.updateView { $0.group = field } }) {
                ForEach(GroupField.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
        }
    }

    private func showToggle(_ title: String, _ keyPath: WritableKeyPath<ViewSettings, Bool>, onEnable: @escaping (Bool) -> Void = { _ in }) -> some View {
        Toggle(title, isOn: Binding {
            SettingsStore.shared.settings.view[keyPath: keyPath]
        } set: {
            SettingsStore.shared.settings.view[keyPath: keyPath] = $0
            onEnable($0)
            SettingsStore.shared.save()
        })
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard !model.isEditingPath, model.renaming == nil, !press.modifiers.contains(.command) else { return .ignored }

        switch press.key {
        case .return:
            Task { await model.open(model.selection) }
            return .handled
        case .delete:
            Task { await model.goUp() }
            return .handled
        case .space:
            model.previewURL = model.previewURL == nil ? model.selectedItems.first?.url : nil
            return .handled
        default:
            break
        }

        guard press.characters.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.union(.punctuationCharacters).contains),
              !press.characters.isEmpty else { return .ignored }

        let prefix = typeAhead.append(press.characters)

        if let match = typeAheadMatch(prefix, in: model.items) {
            model.selection = [match]
        }

        return .handled
    }

    private func loadSections() async {
        sections = await Self.buildSections(excluding: NetworkShares.shared.listedMountPoints)
    }

    // a stat on an unreachable smb share can hang, so the sidebar is built off the main actor
    @concurrent
    private static func buildSections(excluding shares: Set<String>) async -> [SidebarSection] {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []

        return sidebarSections(
            home: FileManager.default.homeDirectoryForCurrentUser,
            volumes: volumes.filter { $0.path(percentEncoded: false) != "/" && !shares.contains($0.folderKey) }
        )
    }
}

#Preview {
    BrowserScreen()
        .frame(width: 1000, height: 600)
}

