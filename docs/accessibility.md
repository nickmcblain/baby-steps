# Accessibility

How the native iOS app (`ios-native/`) supports Apple's accessibility features, and which
App Store Accessibility Nutrition Labels we can honestly declare.

## Common tasks

The labels apply to the app's common tasks:

- Log a feed (timer or manual), a nappy or potty, a sleep, tummy time, a pump, medicine or an activity.
- Read today's summary on Home, and the timeline (list and week views).
- Read feed, sleep, tummy and nappy patterns, and the growth chart.
- Check room temperature and clothing advice.
- Ask a question.
- Add a baby, or join a partner with an invite code.

## Nutrition Labels

| Label | Declare? | Why |
| --- | --- | --- |
| VoiceOver | Yes, once checked on a real device | Every control has a label, and a value where it changes. Cards and timeline rows read as one element. Screen titles and sections are headings. Timeline rows have a Delete action. Timers read as "3 minutes 5 seconds". Charts have audio graphs (`accessibilityChartDescriptor`) and a text summary. |
| Voice Control | Yes | Every button has a name you can say. Icon-only buttons and buttons whose visible text differs from their label have `accessibilityInputLabels` (for example "Add", "Plus" or "Log" for the dock's +). |
| Larger Text | Yes | All app text uses Dynamic Type (`Font.app(…, relativeTo:)`). At accessibility sizes, rows stack vertically, grids drop to one column, fixed-height sheets open full height, the Home date button wraps below the baby's name, and the dock shows icons only and supports the Large Content Viewer. Chart axis ticks are capped, because the chart's text summary and the Bars view carry the same detail at any size. Widgets scale up to the largest size that fits. |
| Dark Interface | Not yet | The app is forced to light mode. The "Dark mode and AA contrast" PR adds dark mode; declare this once it ships. |
| Differentiate Without Colour | Yes | Selected pills show a tick. Timers show a play or pause icon. Sleep and tummy bars differ in width. Week-chart markers become per-type symbols. Log types always have a text label (Feed, Nappy, Wee/Poo, Left/Right). |
| Sufficient Contrast | Not yet | Owned by the "Dark mode and AA contrast" PR (WCAG AA palette). Declare this once it ships, and remove `.contrast` from the audit test's exclusions. |
| Reduced Motion | Yes | Button press shrink becomes a dim. Animated digit transitions on timers and temperature are turned off. Ask's auto-scroll jumps instead of animating. There are no other custom animations. |
| Captions / Audio Descriptions | Not applicable | The app has no video or audio content. |

## Testing

- `ScrunchUITests/AccessibilityAuditTests` runs `performAccessibilityAudit()` on the main
  screens, at the default size and at AX5. Screens are reached with the DEBUG `-debugURL`
  launch argument. The simulator must already be signed in with a baby, or the screens are skipped.
- `ScrunchCoreTests/SpokenTests` covers the spoken copy (durations, chart and day summaries).
- Manual checks before each release:
  - On a device with VoiceOver, log a feed, a nappy and a nap, then read Home's "Today's summary".
  - With Voice Control, say "Show names", then "Tap Log", then "Tap Nappy".
  - At AX5 (Settings > Accessibility > Display & Text Size > Larger Text), check Home, the timers and the pattern charts for clipped text.
