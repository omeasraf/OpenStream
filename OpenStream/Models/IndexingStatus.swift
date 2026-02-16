// MARK: - IndexingStatus

enum IndexingStatus: Equatable {
    case idle
    case indexing(String)
    case complete
}