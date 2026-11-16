import XCTest
@testable import ScrunchCore

final class FreshnessTests: XCTestCase {
  let now = at(2026, 10, 14, 21)

  func testNoLogsIsNoLogs() {
    XCTAssertEqual(HomeCopy.freshness(lastLoggedAt: nil, now: now), .noLogs)
    XCTAssertNil(HomeCopy.lastLoggedAt([nil, nil]))
  }

  func testRecentLogIsFresh() {
    XCTAssertEqual(HomeCopy.freshness(lastLoggedAt: now - 3 * 3_600_000, now: now), .fresh)
  }

  func testOldLogIsStale() {
    let old = now - 10 * DAY
    XCTAssertEqual(HomeCopy.freshness(lastLoggedAt: old, now: now), .stale(lastLoggedAt: old))
  }

  func testLastLoggedAtCountsSleepFromItsEnd() {
    let feed = Event(loggedAt: now - 5 * 3_600_000, kind: .feed)
    let sleep = Event(loggedAt: now - 6 * 3_600_000, kind: .sleep, durationMinutes: 120)
    XCTAssertEqual(HomeCopy.lastLoggedAt([feed, sleep, nil]), now - 4 * 3_600_000)
  }

  func testStaleTitle() {
    XCTAssertEqual(HomeCopy.staleTitle(lastLoggedAt: now - 14 * 3_600_000, now: now, calendar: london), "Nothing logged for 14 hours")
    XCTAssertEqual(HomeCopy.staleTitle(lastLoggedAt: at(2026, 10, 4, 9), now: now, calendar: london), "Nothing logged since Wed 4 Nov")
  }
}

final class TimelineGapTests: XCTestCase {
  let now = at(2026, 10, 14, 21)

  func testGapsBetweenFeedsAndNappies() {
    let feed1 = Event(id: "f1", loggedAt: at(2026, 10, 14, 9), kind: .feed)
    let feed2 = Event(id: "f2", loggedAt: at(2026, 10, 14, 12, 12), kind: .feed)
    let nappy1 = Event(id: "n1", loggedAt: at(2026, 10, 14, 10), kind: .nappy)
    let nappy2 = Event(id: "n2", loggedAt: at(2026, 10, 14, 10, 45), kind: .nappy)
    let gaps = Timeline.gaps([feed2, nappy2, nappy1, feed1], now: now)
    XCTAssertEqual(gaps["f2"], "3h 12m since last feed")
    XCTAssertEqual(gaps["n2"], "45 min since last nappy")
    XCTAssertNil(gaps["f1"])
    XCTAssertNil(gaps["n1"])
  }

  func testNoGapAcrossADayOrMore() {
    let feed1 = Event(id: "f1", loggedAt: at(2026, 10, 12, 9), kind: .feed)
    let feed2 = Event(id: "f2", loggedAt: at(2026, 10, 14, 9), kind: .feed)
    XCTAssertTrue(Timeline.gaps([feed2, feed1], now: now).isEmpty)
  }
}

final class FeedTotalsTests: XCTestCase {
  let end = at(2026, 10, 14, 21)

  func testTotalsPerDayAndAveragesOverLoggedDays() {
    let events = [
      Event(loggedAt: at(2026, 10, 14, 8), kind: .feed, feedKind: .bottle, amountMl: 90),
      Event(loggedAt: at(2026, 10, 14, 11), kind: .feed, feedKind: .bottle, amountMl: 120),
      Event(loggedAt: at(2026, 10, 14, 14), kind: .feed, feedKind: .breast, durationMinutes: 15),
      Event(loggedAt: at(2026, 10, 12, 9), kind: .feed, feedKind: .bottle, amountMl: 60),
      Event(loggedAt: at(2026, 10, 12, 10), kind: .nappy),
      Event(loggedAt: at(2026, 10, 1, 9), kind: .feed, amountMl: 500),
    ]
    let totals = Patterns.feedTotals(events, days: 7, rangeEndMs: end, calendar: london)
    XCTAssertEqual(totals.days.count, 7)
    XCTAssertEqual(totals.days.last?.label, "Sat 14")
    XCTAssertEqual(totals.days.last?.feeds, 3)
    XCTAssertEqual(totals.days.last?.ml, 210)
    XCTAssertEqual(totals.loggedDays, 2)
    XCTAssertEqual(totals.feedsPerDay, 2)
    XCTAssertEqual(totals.mlPerDay, 135)
    XCTAssertEqual(Patterns.perDay(totals.feedsPerDay), "2")
    XCTAssertEqual(Patterns.perDay(6.47), "6.5")
  }

  func testEmptyTotals() {
    let totals = Patterns.feedTotals([], days: 7, rangeEndMs: end, calendar: london)
    XCTAssertEqual(totals.loggedDays, 0)
    XCTAssertEqual(totals.feedsPerDay, 0)
  }

  func testSparseNote() {
    XCTAssertEqual(Patterns.sparseNote(loggedDays: 1, days: 7), "Only 1 day logged in the last 7, so these numbers are rough for now.")
    XCTAssertEqual(Patterns.sparseNote(loggedDays: 2, days: 14), "Only 2 days logged in the last 14, so these numbers are rough for now.")
    XCTAssertNil(Patterns.sparseNote(loggedDays: 0, days: 7))
    XCTAssertNil(Patterns.sparseNote(loggedDays: 3, days: 7))
  }
}

final class AskAnswerTests: XCTestCase {
  func testSplitsTrailingSourcesBlock() {
    let text = """
    Most newborns feed 8 to 12 times a day.

    - Watch for early hunger cues.

    ---
    Sources:
    - NHS – Breastfeeding: how often (https://www.nhs.uk/baby/breastfeeding/)
    - [The Lullaby Trust](https://www.lullabytrust.org.uk)
    - Start4Life
    """
    let (body, sources) = AskAnswer.split(text)
    XCTAssertEqual(body, "Most newborns feed 8 to 12 times a day.\n\n- Watch for early hunger cues.")
    XCTAssertEqual(sources, [
      Citation(title: "NHS – Breastfeeding: how often", url: "https://www.nhs.uk/baby/breastfeeding/"),
      Citation(title: "The Lullaby Trust", url: "https://www.lullabytrust.org.uk"),
      Citation(title: "Start4Life"),
    ])
  }

  func testInlineBoldSourcesLine() {
    let (body, sources) = AskAnswer.split("Keep them cool.\n\n**Sources:** NHS; The Lullaby Trust")
    XCTAssertEqual(body, "Keep them cool.")
    XCTAssertEqual(sources.map(\.title), ["NHS", "The Lullaby Trust"])
  }

  func testLeavesOrdinaryProseAlone() {
    let text = "Sources of iron include meat and lentils."
    let (body, sources) = AskAnswer.split(text)
    XCTAssertEqual(body, text)
    XCTAssertTrue(sources.isEmpty)
  }

  func testMergeDropsRepeats() {
    let merged = AskAnswer.merge(
      [Citation(title: "NHS", url: "https://nhs.uk"), Citation(title: "Start4Life")],
      [Citation(title: "nhs"), Citation(title: "Start4Life"), Citation(title: "Lullaby Trust", url: "https://lullabytrust.org.uk")]
    )
    XCTAssertEqual(merged.map(\.title), ["NHS", "Start4Life", "Lullaby Trust"])
  }
}

final class LogTypesTests: XCTestCase {
  func testPottyOnlyFromFirstBirthday() {
    let now = at(2026, 10, 14)
    XCTAssertFalse(LogTypes.showsPotty(dateOfBirth: now - 90 * DAY, now: now))
    XCTAssertTrue(LogTypes.showsPotty(dateOfBirth: now - 400 * DAY, now: now))
  }
}

/// Copy from #4/#7 now comes from the String Catalog; the en-GB text is unchanged.
final class CatalogCopyTests: XCTestCase {
  func testSparseNoteAgreesWithTheCount() {
    XCTAssertEqual(Patterns.sparseNote(loggedDays: 1, days: 7), "Only 1 day logged in the last 7, so these numbers are rough for now.")
    XCTAssertEqual(Patterns.sparseNote(loggedDays: 2, days: 14), "Only 2 days logged in the last 14, so these numbers are rough for now.")
    XCTAssertNil(Patterns.sparseNote(loggedDays: 3, days: 7))
  }

  func testStaleTitleSingularHour() {
    let now = at(2026, 10, 14, 21)
    XCTAssertEqual(HomeCopy.staleTitle(lastLoggedAt: now - 1 * 3_600_000, now: now, calendar: london), "Nothing logged for 1 hour")
  }

  func testMilestoneSavedReadsNaturally() {
    XCTAssertEqual(MilestoneCopy.saved(.firstSmile, babyName: "Eliza Rose"), "Saved Eliza's first smile")
    XCTAssertEqual(MilestoneCopy.saved(.rolledOver, babyName: "Eliza"), "Saved: Eliza rolled over")
    XCTAssertEqual(MilestoneCopy.saved(.firstTooth, babyName: nil), "First tooth saved")
  }

  func testEverySaveLineHasBothForms() {
    for kind in EventKind.allCases {
      XCTAssertFalse(SaveCopy.logged(kind, babyName: "Ada").isEmpty)
      XCTAssertFalse(SaveCopy.logged(kind, babyName: nil).contains("Ada"))
    }
  }
}
