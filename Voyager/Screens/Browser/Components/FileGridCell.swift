//
//  FileGridCell.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct FileGridCell: View {
    let item: FileItem
    let layout: ViewLayout
    let iconSize: CGFloat
    let compact: Bool
    let leadingInset: CGFloat
    let isSelected: Bool
    let isDropTarget: Bool
    let rename: RenameField?

    private var name: String {
        item.displayName(showingExtension: SettingsStore.shared.settings.view.showExtensions)
    }

    private var gap: CGFloat { compact ? 3 : 6 }

    var body: some View {
        Group {
            switch layout {
            case .smallIcons, .list:
                small
            case .tiles:
                tile
            case .content:
                content
            default:
                icon
            }
        }
        .opacity(item.isHidden ? 0.5 : 1)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        VStack(spacing: gap) {
            FileIcon(item: item, size: iconSize)
                .padding(compact ? 2 : 4)
                .background(highlight, in: .rect(cornerRadius: 8))

            if let rename {
                rename
                    .multilineTextAlignment(.center)
            } else {
                Text(name)
                    .font(SettingsStore.shared.settings.font(scale: 12 / 13))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .foregroundStyle(isSelected ? Color.Mocha.base : Color.primary)
                    .background(isSelected ? Color.userAccent : .clear, in: .rect(cornerRadius: 4))
            }
        }
    }

    private var small: some View {
        HStack(spacing: gap + 2) {
            FileIcon(item: item, size: 16)

            title

            Spacer(minLength: 0)
        }
        .padding(.leading, leadingInset)
        .padding(.horizontal, 4)
        .padding(.vertical, compact ? 1 : 3)
        .background(highlight, in: .rect(cornerRadius: 4))
    }

    private var tile: some View {
        HStack(spacing: gap + 4) {
            FileIcon(item: item, size: 48)

            VStack(alignment: .leading, spacing: 1) {
                title

                Text(item.kind)
                    .font(SettingsStore.shared.settings.font(scale: 11 / 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(sizeText)
                    .font(SettingsStore.shared.settings.font(scale: 11 / 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, leadingInset)
        .padding(compact ? 2 : 4)
        .background(highlight, in: .rect(cornerRadius: 6))
    }

    private var content: some View {
        HStack(spacing: gap + 6) {
            FileIcon(item: item, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                title

                Text(item.kind)
                    .font(SettingsStore.shared.settings.font(scale: 11 / 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(item.modified?.formatted(date: .abbreviated, time: .shortened) ?? "--")
                    .font(SettingsStore.shared.settings.font(scale: 11 / 13))
                    .lineLimit(1)

                Text(sizeText)
                    .font(SettingsStore.shared.settings.font(scale: 11 / 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 2 : 5)
        .background(highlight, in: .rect(cornerRadius: 4))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let rename {
            rename
        } else {
            Text(name)
                .font(SettingsStore.shared.settings.font(scale: 12 / 13))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var sizeText: String {
        item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
    }

    private var highlight: Color {
        if isDropTarget {
            return Color.userAccent.opacity(0.3)
        }

        guard isSelected else { return .clear }

        return layout.isZoomable ? Color.primary.opacity(0.1) : Color.userAccent.opacity(0.3)
    }
}
