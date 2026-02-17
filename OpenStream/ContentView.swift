//
//  ContentView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isMiniPlayerExpanded = false
    @Namespace private var animation

    private var playback: PlaybackController { PlaybackController.shared }

    var body: some View {
        Group {
            if #available(iOS 26, macOS 26, *) {
                OpenTabView()
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tabViewBottomAccessory {
                        OpenPlayerMiniView()
                            .matchedTransitionSource(
                                id: "OpenPlayerMiniView",
                                in: animation
                            )
                            .onTapGesture {
                                isMiniPlayerExpanded = true
                            }
                    }
            } else {
                // Fallback for older versions
                OpenTabView()
                    .safeAreaInset(edge: .bottom) {
                        OpenPlayerMiniView()
                    }
            }
        }
        #if os(iOS)
            .fullScreenCover(isPresented: $isMiniPlayerExpanded) {
                ScrollView {

                }.safeAreaInset(edge: .top, spacing: 0) {
                    OpenPlayerView()
                    .navigationTransition(
                        .zoom(sourceID: "OpenPlayerMiniView", in: animation)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        #else
            .sheet(isPresented: $isMiniPlayerExpanded) {
                OpenPlayerView()
            }
        #endif
        .onAppear {
            if SongLibrary.shared.modelContext == nil {
                SongLibrary.shared.setModelContext(modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
}
