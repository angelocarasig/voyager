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
    @State private var newName = ""

    @AppStorage(Preferences.Key.viewMode) private var viewMode: ViewMode = .list
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
        .onChange(of: model.renaming) {
            newName = model.renaming?.name ?? ""
        }
        .alert("Rename", isPresented: isRenaming, presenting: model.renaming) { item in
            TextField("Name", text: $newName)
            Button("Rename") { Task { await model.rename(item, to: newName) } }
            Button("Cancel", role: .cancel) {}
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
        .task { sections = await Self.loadSections() }
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
        .font(SettingsStore.shared.settings.font())
        .windowBackground(SettingsStore.shared.settings)
        .preferredColorScheme(.dark)
        .tint(Color.Mocha.blue)
        .frame(minWidth: 700, minHeight: 400)
    }

    private var isRenaming: Binding<Bool> {
        Binding { model.renaming != nil } set: { if !$0 { model.renaming = nil } }
    }

    private var needsFullDiskAccess: Binding<Bool> {
        Binding { !askedForFullDiskAccess && !SystemAccess.shared.hasFullDiskAccess } set: { if !$0 { askedForFullDiskAccess = true } }
    }

    private func takeOpenRequest() {
        guard appearsActive, let urls = OpenRequests.shared.take() else { return }

        Task { await model.reveal(urls) }
    }

    private var hasOperationFailure: Binding<Bool> {
        Binding { model.operationFailure != nil } set: { if !$0 { model.operationFailure = nil } }
    }

    // a reload keeps its rows on screen, so only a new folder shows the loading view
    private var isOpeningFolder: Bool {
        model.isLoading && model.items.isEmpty
    }

    @ViewBuilder
    private var content: some View {
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
            } else if viewMode == .grid {
                FileGrid(model: model)
            } else {
                FileTable(model: model)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOpeningFolder)
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
                Button("List", systemImage: "list.bullet") { viewMode = .list }
                    .buttonStyle(.flat(isOn: viewMode == .list))

                Button("Icons", systemImage: "square.grid.2x2") { viewMode = .grid }
                    .buttonStyle(.flat(isOn: viewMode == .grid))
            }
            .labelStyle(.iconOnly)
            .padding(.trailing, 8)
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard !model.isEditingPath, !press.modifiers.contains(.command) else { return .ignored }

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

    // a stat on an unreachable smb share can hang, so the sidebar is built off the main actor
    @concurrent
    private static func loadSections() async -> [SidebarSection] {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []

        return sidebarSections(
            home: FileManager.default.homeDirectoryForCurrentUser,
            volumes: volumes.filter { $0.path(percentEncoded: false) != "/" }
        )
    }
}

#Preview {
    BrowserScreen()
        .frame(width: 1000, height: 600)
}

