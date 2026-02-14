//
//  HomeView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "house.fill").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Home").font(.largeTitle.bold())
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
    }
}

#Preview {
    HomeView()
}
