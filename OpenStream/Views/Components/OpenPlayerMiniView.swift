//
//  OpenPlayerView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI

struct OpenPlayerMiniView: View {
    var onExpand: () -> Void
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            VStack(alignment: .leading) {
                Text("Song Title")
                    .font(.headline)
                Text("Artist Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "play.fill").font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { onExpand() }
        .shadow(radius: 6)
    }
}

#Preview {
    OpenPlayerMiniView(onExpand: {})
}
