//
//  SongLibraryService.swift
//  OpenStream
//

import Foundation
import SwiftData

#if os(macOS)
    @preconcurrency import VLCKit
#else
    import MobileVLCKit
#endif

// MARK: - SongLibrary

@Observable
@MainActor
final class SongLibrary {
    static let shared = SongLibrary()

    private let fileManager = FileManager.default
    private(set) var songs: [LibrarySong] = []
    let songsDirectory: URL

    /// Indexing status for startup and Files app sync. Visible on all pages except OpenPlayerView.
    private(set) var indexingStatus: IndexingStatus = .idle

    var modelContext: ModelContext? {
        didSet {
            if modelContext != nil {
                Task { await indexOnStartup() }
            }
        }
    }

    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "aiff", "wma", "alac", "m4b"
    ]

    private init() {
        let baseDir =
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        songsDirectory = baseDir.appendingPathComponent(
            "Songs",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: songsDirectory,
            withIntermediateDirectories: true
        )
        // Ensure Documents has content so the app folder appears in Files app
        ensureDocumentsPlaceholder(in: baseDir)
    }

    /// Creates a placeholder file in Documents so the OpenStream folder appears in Files app.
    private func ensureDocumentsPlaceholder(in documentsURL: URL) {
        let placeholder = documentsURL.appendingPathComponent("OpenStream.txt", isDirectory: false)
        guard !fileManager.fileExists(atPath: placeholder.path) else { return }
        let text = "OpenStream music library.\nAdd audio files to the Songs folder to import them."
        try? text.write(to: placeholder, atomically: true, encoding: .utf8)
    }

    // MARK: - Indexing

    /// Scans the Songs directory on startup and syncs with the database.
    /// Imports new files (e.g. added via Files app) and removes entries for deleted files.
    func indexOnStartup() async {
        guard let modelContext = modelContext else { return }

        indexingStatus = .indexing("Scanning…")
        defer { indexingStatus = .complete }

        try? fileManager.createDirectory(
            at: songsDirectory,
            withIntermediateDirectories: true
        )

        var descriptor = FetchDescriptor<LibrarySong>()
        let existingSongs: [LibrarySong]
        do {
            existingSongs = try modelContext.fetch(descriptor)
        } catch {
            await loadSongs()
            return
        }

        // 1. Remove DB entries for files that no longer exist
        let existingFileNames = Set(existingSongs.map(\.fileName))
        for song in existingSongs {
            let url = songsDirectory.appendingPathComponent(song.fileName)
            if !fileManager.fileExists(atPath: url.path) {
                modelContext.delete(song)
            }
        }

        // 2. Find audio files on disk
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: songsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            )
        } catch {
            await loadSongs()
            saveContext()
            return
        }

        let audioURLs = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return Self.audioExtensions.contains(ext)
        }

        // 3. Import new files not in DB (files added via Files app or already in place)
        for url in audioURLs {
            let fileName = url.lastPathComponent
            if existingFileNames.contains(fileName) { continue }

            if let song = await importFileInPlace(at: url, modelContext: modelContext) {
                modelContext.insert(song)
            }
        }

        saveContext()
        await loadSongs()
    }

    // MARK: - Public API

    /// Import audio files from the given URLs. On macOS, URLs from fileImporter
    /// must be security-scoped; access is handled inside this method.
    func importFiles(_ urls: [URL]) async {
        guard let modelContext = modelContext else {
            return
        }

        var imported: [LibrarySong] = []

        for url in urls {
            if let song = await importFile(
                from: url,
                modelContext: modelContext
            ) {
                imported.append(song)
            }
        }

        guard !imported.isEmpty else { return }

        for song in imported {
            modelContext.insert(song)
        }
        saveContext()
        await loadSongs()
    }

    func deleteSong(_ song: LibrarySong) async {
        guard let modelContext = modelContext else { return }

        let fileURL = songsDirectory.appendingPathComponent(song.fileName)
        try? fileManager.removeItem(at: fileURL)

        modelContext.delete(song)
        saveContext()
        await loadSongs()
    }

    func getFileURL(for song: LibrarySong) -> URL {
        songsDirectory.appendingPathComponent(song.fileName)
    }

    func getMediaForPlayback(for song: LibrarySong) -> VLCMedia {
        VLCMedia(url: getFileURL(for: song))
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Loading

    private func loadSongs() async {
        guard let modelContext = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<LibrarySong>(
                sortBy: [SortDescriptor(\.importedDate, order: .reverse)]
            )
            let fetched = try modelContext.fetch(descriptor)
            songs = fetched
        } catch {
            songs = []
        }
    }

    // MARK: - Import (single file)

    /// Imports a file already located in songsDirectory (e.g. added via Files app).
    /// Uses the existing filename; does not copy the file.
    private func importFileInPlace(at url: URL, modelContext: ModelContext) async -> LibrarySong? {
        let fileName = url.lastPathComponent
        guard url.deletingLastPathComponent().path == songsDirectory.path else { return nil }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return nil
        }

        let fileHash = fileData.sha256()
        let fileSize = fileData.count

        do {
            var descriptor = FetchDescriptor<LibrarySong>(
                predicate: #Predicate<LibrarySong> { $0.fileHash == fileHash }
            )
            descriptor.fetchLimit = 1
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 { return nil }
        } catch {
            return nil
        }

        let metadata = await AudioMetadataExtractor.extract(from: url)
        return LibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            fileName: fileName,
            fileHash: fileHash,
            size: fileSize,
            duration: metadata.duration,
            lyrics: metadata.lyrics,
            album: metadata.album,
            albumArtist: metadata.albumArtist,
            genre: metadata.genre,
            songDescription: metadata.songDescription,
            trackNumber: metadata.trackNumber,
            discNumber: metadata.discNumber,
            year: metadata.year,
            composer: metadata.composer,
            artwork: metadata.artwork
        )
    }

    /// Imports from an external URL (file importer), copies into songsDirectory.
    private func importFile(from url: URL, modelContext: ModelContext) async
        -> LibrarySong?
    {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return nil
        }

        let fileHash = fileData.sha256()
        let fileSize = fileData.count

        // Skip if already in library
        do {
            var descriptor = FetchDescriptor<LibrarySong>(
                predicate: #Predicate<LibrarySong> { $0.fileHash == fileHash }
            )
            descriptor.fetchLimit = 1
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 { return nil }
        } catch {
            return nil
        }

        let fileName =
            "song_\(UUID().uuidString.prefix(8))_\(url.lastPathComponent)"
        let destinationURL = songsDirectory.appendingPathComponent(fileName)

        do {
            try fileData.write(to: destinationURL)
        } catch {
            return nil
        }

        let metadata = await AudioMetadataExtractor.extract(
            from: destinationURL
        )

        return LibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            fileName: fileName,
            fileHash: fileHash,
            size: fileSize,
            duration: metadata.duration,
            lyrics: metadata.lyrics,
            album: metadata.album,
            albumArtist: metadata.albumArtist,
            genre: metadata.genre,
            songDescription: metadata.songDescription,
            trackNumber: metadata.trackNumber,
            discNumber: metadata.discNumber,
            year: metadata.year,
            composer: metadata.composer,
            artwork: metadata.artwork
        )
    }

    // MARK: - Persistence

    private func saveContext() {
        guard let modelContext = modelContext else { return }
        try? modelContext.save()
    }
}
