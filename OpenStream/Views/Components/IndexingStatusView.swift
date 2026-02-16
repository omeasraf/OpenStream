//
//  IndexingStatusView.swift
//  OpenStream
//

import SwiftUI

struct IndexingStatusView: View {
    private var library: SongLibrary { SongLibrary.shared }

    var body: some View {
        Group {
            switch library.indexingStatus {
            case .idle, .complete:
                EmptyView()
            case .indexing(let message):
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: library.indexingStatus)
    }
}

#Preview("Indexing") {
    VStack {
        IndexingStatusView()
        Spacer()
    }
}
