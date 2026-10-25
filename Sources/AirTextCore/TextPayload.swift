import Foundation

public enum PayloadError: LocalizedError {
    case empty
    case tooLarge
    case invalidText
    case notRegularFile

    public var errorDescription: String? {
        switch self {
        case .empty: return "文本为空，请先输入内容。"
        case .tooLarge: return "文本不能超过 1 MiB。"
        case .invalidText: return "文件不是有效的 UTF-8 文本。"
        case .notRegularFile: return "只能打开普通文本文件，不能打开目录或符号链接。"
        }
    }
}

public enum TextPayload {
    public static let maximumBytes = 1_048_576

    public static func encode(_ text: String) throws -> Data {
        let data = Data(text.utf8)
        guard !data.isEmpty else { throw PayloadError.empty }
        guard data.count <= maximumBytes else { throw PayloadError.tooLarge }
        return data
    }

    public static func read(_ url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw PayloadError.notRegularFile
        }
        guard (values.fileSize ?? 0) <= maximumBytes else { throw PayloadError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw PayloadError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PayloadError.invalidText
        }
        return text
    }
}

public final class OutgoingPayload {
    public let fileURL: URL
    private let directory: URL

    public init(text: String, parent: URL = FileManager.default.temporaryDirectory) throws {
        let data = try TextPayload.encode(text)
        directory = parent.appendingPathComponent("AirText-\(UUID().uuidString)", isDirectory: true)
        fileURL = directory.appendingPathComponent("Text.airtext")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch let cleanupError {
                throw NSError(
                    domain: "AirText",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "无法创建传输文件，且临时目录清理失败：\(cleanupError.localizedDescription)",
                        NSUnderlyingErrorKey: error
                    ]
                )
            }
            throw error
        }
    }

    public func remove() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}
