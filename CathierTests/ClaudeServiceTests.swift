import XCTest
@testable import Cathier

final class ClaudeServiceTests: XCTestCase {

    // MARK: - sampleCheckIns

    func testSampleCheckIns_belowLimit_returnsAll() {
        let checkIns = makeCheckIns(count: 20)
        let sample = ClaudeService.sampleCheckIns(checkIns, limit: 30)
        XCTAssertEqual(sample.count, 20)
    }

    func testSampleCheckIns_atLimit_returnsAll() {
        let checkIns = makeCheckIns(count: 30)
        let sample = ClaudeService.sampleCheckIns(checkIns, limit: 30)
        XCTAssertEqual(sample.count, 30)
    }

    func testSampleCheckIns_aboveLimit_clampsToLimit() {
        let checkIns = makeCheckIns(count: 100)
        let sample = ClaudeService.sampleCheckIns(checkIns, limit: 30)
        XCTAssertLessThanOrEqual(sample.count, 30)
    }

    func testSampleCheckIns_prioritisesTriggerEvents() {
        // Create 50 check-ins; 10 have trigger events
        var checkIns = makeCheckIns(count: 50)
        for i in 0..<10 {
            checkIns[i] = makeCheckIn(index: i, triggerEvent: "trigger-\(i)")
        }
        let sample = ClaudeService.sampleCheckIns(checkIns, limit: 30)
        let triggerCount = sample.filter { !$0.triggerEvent.isEmpty }.count
        // All 10 trigger entries should be included
        XCTAssertEqual(triggerCount, 10)
    }

    func testSampleCheckIns_sortedAscending() {
        let checkIns = makeCheckIns(count: 50)
        let sample = ClaudeService.sampleCheckIns(checkIns, limit: 30)
        for i in 1..<sample.count {
            XCTAssertLessThanOrEqual(sample[i - 1].date, sample[i].date,
                "Result should be sorted oldest → newest")
        }
    }

    // MARK: - buildPatternPrompt

    func testBuildPatternPrompt_containsFocusModeInstructionContext() {
        let checkIns = makeCheckIns(count: 5)
        let prompt = ClaudeService.buildPatternPrompt(
            checkIns: checkIns,
            focus: .triggers,
            contextBrief: "",
            language: .en
        )
        XCTAssertTrue(prompt.contains("Trigger") || prompt.contains("trigger"),
                      "Prompt should reference trigger field for .triggers focus")
    }

    func testBuildPatternPrompt_includesContextBriefWhenPresent() {
        let checkIns = makeCheckIns(count: 3)
        let brief = "I am a software engineer working on a startup."
        let prompt = ClaudeService.buildPatternPrompt(
            checkIns: checkIns,
            focus: .growth,
            contextBrief: brief,
            language: .en
        )
        XCTAssertTrue(prompt.contains(brief),
                      "Prompt should embed the user context brief")
    }

    func testBuildPatternPrompt_omitsContextBriefWhenEmpty() {
        let checkIns = makeCheckIns(count: 3)
        let prompt = ClaudeService.buildPatternPrompt(
            checkIns: checkIns,
            focus: .body,
            contextBrief: "",
            language: .en
        )
        XCTAssertFalse(prompt.contains("User Context"),
                       "Empty context brief should not add a context block")
    }

    func testBuildPatternPrompt_allFocusModes_doNotCrash() {
        let checkIns = makeCheckIns(count: 5)
        for focus in InsightFocusMode.allCases {
            for language in [AppLanguage.zh, .en, .ja] {
                let prompt = ClaudeService.buildPatternPrompt(
                    checkIns: checkIns,
                    focus: focus,
                    contextBrief: "",
                    language: language
                )
                XCTAssertFalse(prompt.isEmpty, "Prompt should not be empty for focus=\(focus) language=\(language)")
            }
        }
    }

    // MARK: - Helpers

    private func makeCheckIns(count: Int) -> [CheckIn] {
        (0..<count).map { makeCheckIn(index: $0) }
    }

    private func makeCheckIn(index: Int, triggerEvent: String = "") -> CheckIn {
        let date = Date(timeIntervalSinceNow: TimeInterval(index * -3600))
        return CheckIn(
            date: date,
            bodyParts: ["head"],
            sensations: ["head:tight"],
            intensity: (index % 10) + 1,
            emotions: ["焦虑"],
            note: "",
            aiFeedback: "",
            triggerEvent: triggerEvent
        )
    }
}
