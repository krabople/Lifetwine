# Lifetwine

**Small moments. Clearer patterns.**

Lifetwine is a private, native iPhone app for logging anything in seconds and discovering useful relationships between daily actions and outcomes.

## What is included

- One-tap logging for ratings, yes/no questions, choices, and current time
- Fast steppers for amounts and durations
- Free-text notes and event details
- Fully custom trackers with colours, symbols, ranges, units, choices, and daily aggregation rules
- A clean chronological journal with search and swipe-to-delete
- A correlation engine that:
  - compares influences with outcomes
  - tests same-day, one-day, and two-day delays
  - combines Pearson and Spearman correlations for outlier resistance
  - uses Benjamini–Hochberg false-discovery-rate adjustment to filter likely coincidences
  - requires at least seven matched days
- Plain-language findings with strength, timing, sample size, and an evidence score
- CSV export
- Local SwiftData storage with no account, ads, analytics, or network service
- A custom 1024×1024 app icon
- Unit tests for strong, delayed, constant-value, and insufficient-data cases

## Open and run

1. Move or sync the `Lifetwine` folder to a Mac with Xcode 16 or later.
2. Open `Lifetwine.xcodeproj`.
3. Select the `Lifetwine` scheme and an iPhone simulator running iOS 17 or later.
4. Press Run.

For a physical iPhone, select your Apple development team under **Signing & Capabilities** and choose a unique bundle identifier if Xcode asks for one.

## Tests

In Xcode, choose **Product → Test**. The included test target exercises the statistical engine without needing network access.

## Privacy and health note

Lifetwine stores data locally. Findings describe associations in personal logs; they do not establish causation and are not medical advice. Medication changes should always be discussed with a qualified clinician.

