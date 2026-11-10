//
//  GroupHeader.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct GroupHeader: View {
    let group: FileGroup
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .frame(width: 12)

                Text(group.title)
                    .fontWeight(.semibold)

                Text("\(group.items.count)")
                    .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
