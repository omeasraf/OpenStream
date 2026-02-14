//
//  OpenPlayerView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI

struct OpenPlayerView: View {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            Spacer()
            
            // Artwork
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 300, height: 300)
            
            VStack(spacing: 4) {
                Text("Song Title")
                    .font(.title2.bold())
                Text("Artist Name")
                    .foregroundStyle(.secondary)
            }
            
            // Controls
            HStack(spacing: 50) {
                Button { } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button { } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 40))
                }
                
                Button { } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        isPresented = false
                    }
                    dragOffset = 0
                }
        )
        .animation(.spring(), value: dragOffset)
    }
}

#Preview {
    @Previewable @State var isMiniPlayerExpanded = true;
    OpenPlayerView(isPresented: $isMiniPlayerExpanded)
}
