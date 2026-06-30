import XCTest
@testable import WorktreeCore

final class L10nTests: XCTestCase {
    func testEnglishLookup() {
        XCTAssertEqual(L10n.string(.create, language: .en), "Create")
    }
    func testTurkishLookup() {
        XCTAssertEqual(L10n.string(.create, language: .tr), "Oluştur")
    }
    func testEveryKeyHasBothLanguages() {
        for key in L10nKey.allCases {
            XCTAssertFalse(L10n.string(key, language: .en).isEmpty, "EN missing: \(key)")
            XCTAssertFalse(L10n.string(key, language: .tr).isEmpty, "TR missing: \(key)")
        }
    }
    func testWorktreeCountPluralizes() {
        XCTAssertEqual(L10n.worktreeCount(1, language: .en), "1 worktree")
        XCTAssertEqual(L10n.worktreeCount(3, language: .en), "3 worktrees")
        XCTAssertEqual(L10n.worktreeCount(3, language: .tr), "3 worktree")
    }
    func testLanguageLabels() {
        XCTAssertEqual(Language.en.label, "English")
        XCTAssertEqual(Language.tr.label, "Türkçe")
    }
}
