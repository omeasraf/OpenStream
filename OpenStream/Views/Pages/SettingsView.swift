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
    @State private var settings: AppSettings?

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

            // Library organization settings
            if let settings = settings {
                Section {
                    Toggle("Group Songs by Album", isOn: Binding(
                        get: { settings.groupSongsByAlbum },
                        set: { newValue in
                            settings.groupSongsByAlbum = newValue
                            saveSettings()
                        }
                    ))
                    .help("Organize songs into album folders when importing. Artwork is automatically extracted and cached.")
                } header: {
                    Text("Library Organization")
                } footer: {
                    Text("Enable to organize your library by album. Disable to keep all songs in the root directory.")
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
            loadSettings()
        }
    }

    private func loadSettings() {
        settings = AppSettings.getOrCreate(in: modelContext)
    }

    private func saveSettings() {
        guard let settings = settings else { return }
        try? modelContext.save()
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
