import XCTest
@testable import AirTextCore

final class TextPayloadTests: XCTestCase {
    func testUnicodeAndWhitespaceRoundTrip() throws {
        let text = "  key-example-not-a-secret\n中文 🔑\n"
        let payload = try OutgoingPayload(text: text)
        defer { try? payload.remove() }
        XCTAssertEqual(try TextPayload.read(payload.fileURL), text)
        let attributes = try FileManager.default.attributesOfItem(atPath: payload.fileURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let parentAttributes = try FileManager.default.attributesOfItem(
            atPath: payload.fileURL.deletingLastPathComponent().path
        )
        XCTAssertEqual((parentAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        try payload.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: payload.fileURL.path))
        XCTAssertNoThrow(try payload.remove())
    }

    func testByteLimit() throws {
        XCTAssertThrowsError(try TextPayload.encode(""))
        XCTAssertEqual(
            try TextPayload.encode(String(repeating: "a", count: TextPayload.maximumBytes)).count,
            TextPayload.maximumBytes
        )
        XCTAssertThrowsError(
            try TextPayload.encode(String(repeating: "a", count: TextPayload.maximumBytes + 1))
        )
        XCTAssertThrowsError(
            try TextPayload.encode(String(repeating: "中", count: TextPayload.maximumBytes / 3 + 1))
        )
        XCTAssertNoThrow(try TextPayload.encode(" \n "))
    }

    func testRejectInvalidInputFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirTextTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("invalid.airtext")
        try Data([0xff, 0xfe]).write(to: file)
        XCTAssertThrowsError(try TextPayload.read(file))
        XCTAssertThrowsError(try TextPayload.read(directory))
        XCTAssertThrowsError(try TextPayload.read(directory.appendingPathComponent("missing.airtext")))
        let link = directory.appendingPathComponent("link.airtext")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try TextPayload.read(link))
        try Data(repeating: 65, count: TextPayload.maximumBytes + 1).write(to: file)
        XCTAssertThrowsError(try TextPayload.read(file))
    }
}
