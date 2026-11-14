import XCTest
@testable import ScrunchCore

final class InsightsTests: XCTestCase {
  let now = at(2026, 10, 14, 14, 0)

  func baby(ageDays: Double = 20, grams: Double = 4200, mode: FeedingMode? = .breast, roomTemp: Double? = nil) -> Baby {
    Baby(id: "b1", name: "Ada", dateOfBirth: now - ageDays * DAY, weightGrams: grams, lastRoomTempC: roomTemp, feedingMode: mode)
  }

  func feed(_ hour: Int, _ minute: Int = 0, side: Side? = nil, kind: FeedKind = .breast) -> Event {
    Event(loggedAt: at(2026, 10, 14, hour, minute), kind: .feed, feedKind: kind, side: side)
  }

  func input(
    _ baby: Baby, feeds: [Event] = [], nappy: Event? = nil, sleepEnd: EpochMs? = nil, asleep: Bool = false, now: EpochMs? = nil
  ) -> InsightInput {
    InsightInput(baby: baby, now: now ?? self.now, recentFeeds: feeds, lastNappy: nappy, lastSleepEndMs: sleepEnd, asleep: asleep)
  }

  // MARK: Next feed

  func testNoFeedsAsksForALog() {
    let insight = Insights.nextFeed(input(baby()), calendar: london)
    XCTAssertEqual(insight?.headline, "Log a feed to see when the next is likely")
    XCTAssertEqual(insight?.detail, "We'll start with typical gaps for Ada's age.")
  }

  func testThinDataFallsBackToAgeNorm() {
    // One feed at 1pm, 20 days old breastfed → about 2.5 hours → 3:30 pm.
    let insight = Insights.nextFeed(input(baby(), feeds: [feed(13)]), calendar: london)
    XCTAssertEqual(insight?.headline, "Next feed likely around 3:30 pm")
    XCTAssertEqual(insight?.detail, "Last feed 1h ago · typical at this age is about 2.5 hours")
  }

  func testPersonalRhythmUsesMedianGap() {
    // Gaps 3h, 3h, 2h40m → median 3h. Last feed 12:40 → 3:40 pm.
    let feeds = [feed(4), feed(7), feed(10), feed(12, 40)]
    let insight = Insights.nextFeed(input(baby(), feeds: feeds.shuffled()), calendar: london)
    XCTAssertEqual(insight?.headline, "Next feed likely around 3:40 pm")
    XCTAssertEqual(insight?.detail, "Last feed 1h 20m ago · based on the last 4 feeds")
  }

  func testSplitAndMissedLogsAreIgnoredAndDuplicatesDropped() {
    // 10-minute split (ignored) and a 7h gap (ignored) leave too few gaps → age norm.
    let duplicate = feed(13)
    let feeds = [feed(3), feed(10), feed(10, 10), duplicate, duplicate]
    let insight = Insights.nextFeed(input(baby(), feeds: feeds), calendar: london)
    XCTAssertEqual(insight?.detail, "Last feed 1h ago · typical at this age is about 2.5 hours")
  }

  func testOverdueSaysMayBeDueNow() {
    let insight = Insights.nextFeed(input(baby(), feeds: [feed(10, 30)]), calendar: london)
    XCTAssertEqual(insight?.headline, "Feed may be due now")
    XCTAssertEqual(insight?.detail, "Last feed 3h 30m ago · watch for hunger cues")
  }

  func testStaleFeedDoesNotGuess() {
    let insight = Insights.nextFeed(input(baby(), feeds: [feed(5)]), calendar: london)
    XCTAssertEqual(insight?.headline, "No feed logged for 9h")
    XCTAssertEqual(insight?.detail, "Log feeds as they happen and the estimate comes back.")
  }

  func testBottleBiasLengthensTheNorm() {
    let insight = Insights.nextFeed(input(baby(mode: .bottle), feeds: [feed(13, kind: .bottle)]), calendar: london)
    XCTAssertEqual(insight?.headline, "Next feed likely around 4:00 pm")
  }

  // MARK: Breast side

  func testBreastSideSuggestsTheOtherSide() {
    let feeds = [feed(10, side: .right), feed(12, side: .left), feed(13, kind: .bottle)]
    let insight = Insights.breastSide(input(baby(mode: .mixed), feeds: feeds))
    XCTAssertEqual(insight?.headline, "Last side: left")
    XCTAssertEqual(insight?.detail, "Try starting on the right next time.")
  }

  func testBreastSideHiddenWhenBottleOnlyOrOld() {
    XCTAssertNil(Insights.breastSide(input(baby(mode: .bottle), feeds: [feed(12, side: .left)])))
    let old = Event(loggedAt: now - 13 * hourMs, kind: .feed, feedKind: .breast, side: .left)
    XCTAssertNil(Insights.breastSide(input(baby(), feeds: [old])))
    XCTAssertEqual(Insights.breastSide(input(baby(), feeds: [feed(12, side: .both)]))?.headline, "Last feed: both sides")
  }

  // MARK: Nappy

  func testLastNappy() {
    let nappy = Event(loggedAt: at(2026, 10, 14, 11, 55), kind: .nappy, nappy: .both)
    let insight = Insights.lastNappy(input(baby(), nappy: nappy), calendar: london)
    XCTAssertEqual(insight?.headline, "Last nappy 2h 5m ago")
    XCTAssertEqual(insight?.detail, "Wee + poo at 11:55 am")
  }

  func testNappyEmptyAndStale() {
    XCTAssertEqual(Insights.lastNappy(input(baby()))?.headline, "No nappies logged yet")
    let old = Event(loggedAt: now - 30 * hourMs, kind: .nappy, nappy: .wee)
    XCTAssertEqual(Insights.lastNappy(input(baby(), nappy: old))?.headline, "No nappy logged for 30h")
  }

  // MARK: Awake

  func testAwakeWithinTypicalRange() {
    let insight = Insights.awake(input(baby(ageDays: 50), sleepEnd: now - 70 * minuteMs))
    XCTAssertEqual(insight?.headline, "Awake for 1h 10m")
    XCTAssertEqual(insight?.detail, "Typical at this age: 1h–1h 30m. Tired signs matter more than the clock.")
  }

  func testAwakeLongerThanUsual() {
    let insight = Insights.awake(input(baby(ageDays: 10), sleepEnd: now - 75 * minuteMs))
    XCTAssertEqual(insight?.headline, "Awake 1h 15m, longer than usual")
    XCTAssertEqual(insight?.detail, "Typical at this age: 35m–1h. Look for yawns, rubbing eyes or staring.")
  }

  func testAwakeHiddenWhenAsleepUnknownOrStale() {
    XCTAssertNil(Insights.awake(input(baby(), sleepEnd: now - 30 * minuteMs, asleep: true)))
    XCTAssertNil(Insights.awake(input(baby())))
    XCTAssertNil(Insights.awake(input(baby(), sleepEnd: now - 7 * hourMs)))
  }

  func testTypicalAwakeBands() {
    XCTAssertEqual(Insights.typicalAwake(dateOfBirth: now - 100 * DAY, now: now), WakeRange(lowMin: 75, highMin: 120))
    XCTAssertEqual(Insights.typicalAwake(dateOfBirth: now - 400 * DAY, now: now), WakeRange(lowMin: 240, highMin: 360))
  }

  // MARK: TOG

  func testTonightTogFromSavedRoomTemp() {
    let insight = Insights.tonightTog(input(baby(ageDays: 120, grams: 6500, roomTemp: 17)))
    XCTAssertEqual(insight?.headline, "Tonight at 17°C: 2.5 TOG")
    XCTAssertEqual(insight?.detail, "Vest, sleepsuit, 2.5 TOG sleeping bag")
    let newborn = Insights.tonightTog(input(baby(roomTemp: 21.5)))
    XCTAssertEqual(newborn?.headline, "Tonight at 21.5°C: 1.0 TOG")
    XCTAssertEqual(newborn?.detail, "Extra vest (newborn / smaller baby), vest, 1.0 TOG bag or light sleepsuit")
  }

  func testTonightTogWithoutRoomTempAsksForIt() {
    XCTAssertEqual(Insights.tonightTog(input(baby()))?.detail, "Set the room temperature for a TOG suggestion.")
  }

  // MARK: All

  func testAllKeepsAStableOrder() {
    let nappy = Event(loggedAt: now - hourMs, kind: .nappy, nappy: .wee)
    let kinds = Insights.all(
      input(baby(roomTemp: 19), feeds: [feed(13, side: .left)], nappy: nappy, sleepEnd: now - 20 * minuteMs),
      calendar: london
    ).map(\.kind)
    XCTAssertEqual(kinds, [.nextFeed, .breastSide, .lastNappy, .awake, .tonightTog])
  }

  func testSpan() {
    XCTAssertEqual(Insights.span(0), "0m")
    XCTAssertEqual(Insights.span(45 * minuteMs + 59_000), "45m")
    XCTAssertEqual(Insights.span(2 * hourMs), "2h")
    XCTAssertEqual(Insights.span(80 * minuteMs), "1h 20m")
  }

  // MARK: Ask and sharing

  func testAskAlwaysSaysWhereItCameFrom() {
    XCTAssertEqual(AskSafety.sourceLines(nil), [Citation(title: AskSafety.noSourceNote, url: nil)])
    XCTAssertEqual(AskSafety.sourceLines([]).count, 1)
    let nhs = Citation(title: "Sleep — NHS", url: "https://www.nhs.uk/")
    XCTAssertEqual(AskSafety.sourceLines([nhs]), [nhs])
    XCTAssertTrue(AskSafety.helpLine.contains("111"))
    XCTAssertTrue(AskSafety.helpLine.contains("999"))
    XCTAssertTrue(AskSafety.helpLine.contains("GP"))
  }

  func testPartnerInviteMessage() {
    let message = PartnerInvite.message(babyName: "Ada", code: "P8GU2T")
    XCTAssertTrue(message.contains("Ada's feeds, sleeps and nappies"))
    XCTAssertTrue(message.hasSuffix("tap Join with a code and enter P8GU2T."))
  }
}
