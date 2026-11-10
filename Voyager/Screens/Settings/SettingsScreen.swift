//
//  SettingsScreen.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct SettingsScreen: View {
    @State private var section: SettingSection? = .appearance
    @State private var query = ""

    private let store = SettingsStore.shared
    private let access = SystemAccess.shared
    private let families = NSFontManager.shared.availableFontFamilies.sorted()

    private var keys: [SettingKey] {
        query.isEmpty ? (section ?? .appearance).keys : SettingKey.allCases.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .safeAreaInset(edge: .top) { searchField }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let error = store.loadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 8))
                            .padding(.bottom, 12)
                    }

                    if keys.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }

                    ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                        if index > 0 {
                            Divider()
                        }

                        row(for: key)
                    }
                }
                .padding(24)
            }
        }
        .font(store.settings.font())
        .windowBackground(store.settings)
        .preferredColorScheme(.dark)
        .tint(Color.Mocha.blue)
        .frame(minWidth: 720, minHeight: 460)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15)))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(query.isEmpty ? (section ?? .appearance).title : "Results")
                    .font(store.settings.font(scale: 1.4))
                    .fontWeight(.semibold)

                Text("~/.config/voyager/settings.json")
                    .font(store.settings.font(scale: 0.9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Edit in settings.json", systemImage: "curlybraces", action: store.openFile)
        }
        .padding(.bottom, 16)
    }

    private func row(for key: SettingKey) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(key.title)

                Text(key.detail)
                    .font(store.settings.font(scale: 0.9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let warning = warning(for: key) {
                    Text(warning)
                        .font(store.settings.font(scale: 0.9))
                        .foregroundStyle(Color.orange)
                }
            }

            Spacer(minLength: 24)

            control(for: key)
                .frame(width: 240, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    private func warning(for key: SettingKey) -> String? {
        switch key {
        case .fontFamily where !store.settings.isFontInstalled:
            "\u{201C}\(store.settings.fontFamily)\u{201D} is not installed, so the system font is used."
        case .fullDiskAccess where !access.hasFullDiskAccess:
            "Not granted. Drag Voyager from the Finder window into the list, turn it on, then reopen Voyager."
        case .defaultFileManager:
            access.failure
        default:
            nil
        }
    }

    @ViewBuilder
    private func control(for key: SettingKey) -> some View {
        switch key {
        case .fullDiskAccess:
            if access.hasFullDiskAccess {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open Privacy Settings", action: access.openPrivacySettings)
            }
        case .defaultFileManager:
            if access.isDefaultFileManager {
                Button("Restore Finder", action: access.restoreFinder)
            } else {
                Button("Make Voyager the Default", action: access.makeDefault)
            }
        case .fontFamily:
            Picker("Font Family", selection: binding(\.fontFamily)) {
                Text("System Font").tag("")

                if !store.settings.isFontInstalled {
                    Text(store.settings.fontFamily).tag(store.settings.fontFamily)
                }

                Divider()

                ForEach(families, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
        case .fontSize:
            Stepper(value: binding(\.fontSize), in: AppSettings.fontSizes, step: 1) {
                Text("\(Int(store.settings.fontSize)) pt")
                    .monospacedDigit()
            }
        case .backgroundBlur:
            slider(\.backgroundBlur, in: AppSettings.blurs, step: 1) { "\(Int($0))" }
        case .backgroundDim:
            slider(\.backgroundDim, in: AppSettings.dims, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
        }
    }

    // dragging previews live and writes the file once on release
    private func slider(_ keyPath: WritableKeyPath<AppSettings, Double>, in range: ClosedRange<Double>, step: Double, label: (Double) -> String) -> some View {
        let value = Binding {
            store.settings[keyPath: keyPath]
        } set: {
            store.settings[keyPath: keyPath] = ($0 / step).rounded() * step
        }

        return HStack {
            Slider(value: value, in: range) { editing in
                if !editing {
                    store.save()
                }
            }

            Text(label(value.wrappedValue))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding {
            store.settings[keyPath: keyPath]
        } set: {
            store.settings[keyPath: keyPath] = $0
            store.save()
        }
    }
}
