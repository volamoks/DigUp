import Foundation
import Testing
@testable import DigUpKit

@Suite struct NameQueryTests {
    let folder: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DigUpTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    @Test func thePrefixIsOnlyAtTheStart() {
        #expect(NameQuery.text(of: "name: invoice") == "invoice")
        #expect(NameQuery.text(of: "  NAME:  Invoice  ") == "Invoice")
        #expect(NameQuery.text(of: "name:") == "")
        #expect(NameQuery.text(of: "filename: invoice") == nil)
        #expect(NameQuery.text(of: "invoice name:") == nil)
    }

    @Test func nameOnlyLooksAtWhatFilesAreCalledNotWhatIsInside() throws {
        let store = try IndexStore(directory: folder)
        func add(_ path: String, _ body: String) throws {
            let id = try store.insert(Candidate(path: path, kind: .doc, size: 1, mtime: 1,
                                                inode: UInt64(path.count), device: 1))
            try store.addSegment(file: id, kind: .chunk, modality: .text, loc: 1, text: body)
        }
        try add("/notes/quarterly-report.txt", "Lunch with the team on Friday.")
        try add("/notes/lunch.txt", "The quarterly report is due on Monday.")
        let searcher = try Searcher(store: store, loadVectors: false)
        // "quarterly" is in the first file's name and in the second file's text, so plain search finds both.
        #expect(Set(try searcher.search("quarterly", queryVector: nil).map(\.path))
                == ["/notes/quarterly-report.txt", "/notes/lunch.txt"])
        // "name:" keeps only the one that is called that.
        let named = try searcher.search("name: quarterly", queryVector: nil)
        #expect(named.map(\.path) == ["/notes/quarterly-report.txt"])
        #expect(named.first?.segment == .name)
        #expect(named.first?.excerpt?.contains("«quarterly»") == true)
        // A word of a file's name is found; the same word only inside another file is not.
        #expect(try searcher.search("name: report", queryVector: nil).map(\.path) == ["/notes/quarterly-report.txt"])
        #expect(try searcher.search("name: monday", queryVector: nil).isEmpty)
    }
}
