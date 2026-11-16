import AppIntents

/// Siri and Spotlight phrases. Apple requires the app name in every phrase and allows ten
/// shortcuts; height, activity and custom logs are still in the Shortcuts app.
struct ScrunchShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogNappyIntent(),
      phrases: [
        "Log a \(\.$nappy) nappy in \(.applicationName)",
        "Log a \(\.$nappy) nappy with \(.applicationName)",
        "\(.applicationName) \(\.$nappy) nappy",
        "Log a nappy in \(.applicationName)",
      ],
      shortTitle: "Log a nappy",
      systemImageName: "circle.grid.2x2.fill"
    )
    AppShortcut(
      intent: StartTimerIntent(),
      phrases: [
        "Start a \(\.$timer) in \(.applicationName)",
        "Start a \(\.$timer) with \(.applicationName)",
        "Start a \(\.$timer) timer in \(.applicationName)",
        "Start \(\.$timer) in \(.applicationName)",
      ],
      shortTitle: "Start a timer",
      systemImageName: "timer"
    )
    AppShortcut(
      intent: StopTimerIntent(),
      phrases: [
        "Stop the timer in \(.applicationName)",
        "Stop the \(.applicationName) timer",
        "End the feed in \(.applicationName)",
        "End the nap in \(.applicationName)",
      ],
      shortTitle: "Stop the timer",
      systemImageName: "stop.circle"
    )
    AppShortcut(
      intent: LogFeedIntent(),
      phrases: [
        "Log a \(\.$feed) feed in \(.applicationName)",
        "Log a feed in \(.applicationName)",
        "Log a bottle in \(.applicationName)",
      ],
      shortTitle: "Log a feed",
      systemImageName: "drop.fill"
    )
    AppShortcut(
      intent: LogSleepIntent(),
      phrases: ["Log a nap in \(.applicationName)", "Log a sleep in \(.applicationName)"],
      shortTitle: "Log a sleep",
      systemImageName: "moon.fill"
    )
    AppShortcut(
      intent: LogTummyIntent(),
      phrases: ["Log tummy time in \(.applicationName)"],
      shortTitle: "Log tummy time",
      systemImageName: "figure.arms.open"
    )
    AppShortcut(
      intent: LogPumpIntent(),
      phrases: ["Log a pump in \(.applicationName)", "Log expressing in \(.applicationName)"],
      shortTitle: "Log a pump",
      systemImageName: "drop.circle"
    )
    AppShortcut(
      intent: LogPottyIntent(),
      phrases: ["Log a \(\.$nappy) potty visit in \(.applicationName)", "Log the potty in \(.applicationName)"],
      shortTitle: "Log a potty visit",
      systemImageName: "toilet"
    )
    AppShortcut(
      intent: LogMedicineIntent(),
      phrases: ["Log a medicine in \(.applicationName)", "Log a dose in \(.applicationName)"],
      shortTitle: "Log a medicine",
      systemImageName: "pills.fill"
    )
    AppShortcut(
      intent: LogWeightIntent(),
      phrases: ["Log a weight in \(.applicationName)", "Log a weigh-in in \(.applicationName)"],
      shortTitle: "Log a weight",
      systemImageName: "scalemass.fill"
    )
  }
}
