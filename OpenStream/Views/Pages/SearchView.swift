//
//  SearchView.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/15/26.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    var body: some View {
        NavigationStack {
            List {

            }
            .navigationTitle("Search")
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: Text("Search...")
            )
        }
    }
}

#Preview {
    SearchView()
}
