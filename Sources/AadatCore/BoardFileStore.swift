import Foundation

/// Reads and writes the board as one JSON file in `~/Library/Application Support/Aadat/`.
///
/// Safety rule: this is the only code in the app that writes files. Every write goes through
/// `write(_:to:)`, which accepts only the two fixed file names below inside `directory`.
public struct BoardFileStore: Sendable {
    public static let folderName = "Aadat"
    static let boardFileName = "board.json"
    static let quarantineFileName = "board.unreadable.json"
    static let schemaVersion = 1

    public enum StoreError: Error, LocalizedError {
        case unsupportedSchema(Int)
        case pathOutsideStore(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let version):
                "Your tasks were saved by a newer version of Aadat (schema \(version))."
            case .pathOutsideStore(let path):
                "Refusing to write outside the app's data folder: \(path)"
            }
        }
    }

    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent(Self.boardFileName, isDirectory: false) }
    var quarantineURL: URL { directory.appendingPathComponent(Self.quarantineFileName, isDirectory: false) }

    /// - Parameter applicationSupportDirectory: the parent folder. Production code uses `standard()`;
    ///   tests pass a temporary directory.
    public init(applicationSupportDirectory: URL) {
        directory = applicationSupportDirectory
            .appendingPathComponent(Self.folderName, isDirectory: true)
            .standardizedFileURL
    }

    public static func standard() throws -> BoardFileStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return BoardFileStore(applicationSupportDirectory: base)
    }

    /// Loads the board. A missing file yields nil. An unreadable file is copied aside
    /// (so nothing is silently lost) and nil is returned.
    public func load() throws -> DayBoard? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }

        do {
            let file = try Self.decoder.decode(BoardFile.self, from: data)
            guard file.schemaVersion <= Self.schemaVersion else {
                throw StoreError.unsupportedSchema(file.schemaVersion)
            }
            return file.board
        } catch let error as StoreError {
            // Never overwrite a file written by a newer version.
            throw error
        } catch {
            try write(data, to: quarantineURL)
            return nil
        }
    }

    public func save(_ board: DayBoard) throws {
        let data = try Self.encoder.encode(BoardFile(schemaVersion: Self.schemaVersion, board: board))
        try write(data, to: fileURL)
    }

    /// The single write path. Atomic (temporary file, then rename).
    private func write(_ data: Data, to url: URL) throws {
        let target = url.standardizedFileURL
        guard target == fileURL.standardizedFileURL || target == quarantineURL.standardizedFileURL else {
            throw StoreError.pathOutsideStore(target.path)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: target, options: [.atomic])
    }

    private struct BoardFile: Codable {
        var schemaVersion: Int
        var board: DayBoard
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
