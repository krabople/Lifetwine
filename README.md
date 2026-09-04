# Lifetwine

**Small moments. Clearer patterns.**

Lifetwine is a private, native iPhone app for logging anything in seconds and discovering useful relationships between daily actions and outcomes.

## What is included

- Unlimited user-created trackers for ratings, measurements, counters, durations, yes/no answers, single or multiple choices, times, medications, events, and notes
- One-tap values, editable prompts, custom answer labels, colours, symbols, ranges, units, choices, and daily aggregation rules
- A reusable medication list with usual dose and unit, while keeping every logged dose editable
- A searchable universal logger plus a fully customisable and reorderable Today screen
- Backdated logging with shortcuts for now, an hour ago, earlier today, yesterday, or any previous date
- A clean chronological journal with search, edit, repeat, and delete actions
- Siri and Shortcuts support, an app-icon Quick Log action, and `lifetwine://log` deep linking
- A correlation engine that:
  - compares influences with outcomes
  - tests same-day, one-day, and two-day delays
  - combines Pearson and Spearman correlations for outlier resistance
  - uses Benjamini–Hochberg false-discovery-rate adjustment to filter likely coincidences
  - treats structured selections and individual medications as separate signals
  - keeps free text searchable but deliberately excludes it from numerical correlations
  - requires at least seven matched days before showing a tentative comparison
- Plain-language findings with strength, timing, sample size, and an evidence score
- 21 days of clearly labelled sample history, removable at any time, for immediately exploring Patterns
- CSV export
- Local SwiftData storage with no account, ads, analytics, or network service
- A custom 1024×1024 app icon
- Unit tests for strong, delayed, constant-value, insufficient-data, free-text exclusion, and multi-choice cases

## Open and run

1. Move or sync the `Lifetwine` folder to a Mac with Xcode 16 or later.
2. Open `Lifetwine.xcodeproj`.
3. Select the `Lifetwine` scheme and an iPhone simulator running iOS 17 or later.
4. Press Run.

The project is configured for Apple team `6YYA8L76Y8` with bundle identifier `com.krabople.lifetwine`.

## Tests

In Xcode, choose **Product → Test**. The included test target exercises the statistical engine without needing network access.

## TestFlight

The manual **Release to TestFlight** GitHub workflow creates a signed App Store IPA, preserves it as a private build artifact, uploads it to TestFlight, and waits for Apple to finish processing it. Apple signing credentials are held only as encrypted repository secrets.

## Privacy and health note

Lifetwine stores data locally. Findings describe associations in personal logs; they do not establish causation and are not medical advice. Medication changes should always be discussed with a qualified clinician.

