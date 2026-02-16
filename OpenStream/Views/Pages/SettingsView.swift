//
//  SettingsView.swift
//  OpenStream
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingFileImporter = false
    @State private var importError: String?
    @State private var isImporting = false

    private var library: SongLibrary { SongLibrary.shared }

    var body: some View {
        List {
            Section {
                Button {
                    isPresentingFileImporter = true
                } label: {
                    Label("Import Songs", systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting)
            }

            if isImporting {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Importing…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = importError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if library.songs.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text(
                            "Tap \"Import Songs\" to add audio files from your device."
                        )
                    )
                } else {
                    ForEach(library.songs) { song in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Library")
            }
        }
        .navigationTitle("Settings")
        .fileImporter(
            isPresented: $isPresentingFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            Task { @MainActor in
                await handleFileImport(result)
            }
        }
        .onAppear {
            if library.modelContext == nil {
                library.setModelContext(modelContext)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        importError = nil
        isImporting = true
        defer { isImporting = false }

        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }

            if library.modelContext == nil {
                library.setModelContext(modelContext)
            }
            await library.importFiles(urls)
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [LibrarySong.self], inMemory: true)
}
