# Changelog
All notable changes to this project will be documented in this file.

## [1.2] - Unreleased

### Added
- Ability to add event metadata plausible/analytics#381
- Add tracker module to automatically track outbound links  plausible/analytics#389
- Display weekday on the visitor graph plausible/analytics#175
- Collect and display browser & OS versions plausible/analytics#397
- Simple notifications around traffic spikes plausible/analytics#453
- Dark theme option/system setting follow plausible/analytics#467
- "Load More" capability to pages modal plausible/analytics#480
- Unique Visitors (last 30 min) as a top stat in realtime view plausible/analytics#500
- Pinned filter and date selector rows while scrolling plausible/analytics#472
- Escape keyboard shortcut to clear all filters plausible/analytics#625
- Keybindings for selecting dates/ranges plausible/analytics#630

### Changed
- Use alpine as base image to decrease Docker image size plausible/analytics#353
- Ignore automated browsers (Phantom, Selenium, Headless Chrome, etc)
- Display domain's favicon on the home page
- Ignore consecutive pageviews on same pathname plausible/analytics#417
- Validate domain format on site creation plausible/analytics#427
- Improve settings UX and design plausible/analytics#412
- Improve site listing UX and design plausible/analytics#438
- Improve onboarding UX and design plausible/analytics#441
- Allows outbound link tracking script to use new tab redirection plausible/analytics#494
- "This Month" view is now Month-to-date for the current month plausible/analytics#491
- My sites now show settings cog at all times on smaller screens plausible/analytics#497
- Background jobs are enabled by default for self-hosted installations plausible/analytics#603
- All new users on self-hosted installations have a never-ending trial plausible/analytics#603
- Changed caret/chevron color in datepicker and filters dropdown

### Fixed
- Do not error when activating an already activated account plausible/analytics#370
- Ignore arrow keys when modifier keys are pressed plausible/analytics#363
- Show correct stats when goal filter is combined with source plausible/analytics#374
- Going back in history now correctly resets the period filter plausible/analytics#408
- Fix URL decoding in query parameters plausible/analytics#416
- Fix overly-sticky date in query parameters plausible/analytics/#439
- Prevent picking dates before site insertion plausible/analtics#446
- Fix overly-sticky from and to in query parameters plausible/analytics#495
- Adds support for single-day date selection plausible/analytics#495
- Goal conversion rate in realtime view is now accurate plausible/analytics#500
- Various UI/UX issues plausible/analytics#503

### Security
- Do not run the plausible Docker container as root plausible/analytics#362

## [1.1.1] - 2020-10-14

### Fixed
- Revert Dockerfile change that introduced a regression

## [1.1.0] - 2020-10-14

### Added
- Linkify top pages [plausible/analytics#91](https://github.com/plausible/analytics/issues/91)
- Filter by country, screen size, browser and operating system  [plausible/analytics#303](https://github.com/plausible/analytics/issues/303)

### Fixed
- Fix issue with creating a PostgreSQL database when `?ssl=true` [plausible/analytics#347](https://github.com/plausible/analytics/issues/347)
- Do no disclose current URL to DuckDuckGo's favicon service [plausible/analytics#343](https://github.com/plausible/analytics/issues/343)
- Updated UAInspector database to detect newer devices [plausible/analytics#309](https://github.com/plausible/analytics/issues/309)

## [1.0.0] - 2020-10-06

### Added
- Collect and present link tags (`utm_medium`, `utm_source`, `utm_campaign`) in the dashboard

### Changed
- Replace configuration parameters `CLICKHOUSE_DATABASE_{HOST,NAME,USER,PASSWORD}` with a single `CLICKHOUSE_DATABASE_URL` [plausible/analytics#317](https://github.com/plausible/analytics/pull/317)
- Disable subscriptions by default
- Remove `CLICKHOUSE_DATABASE_POOLSIZE`, `DATABASE_POOLSIZE` and `DATABASE_TLS_ENABLED` parameters. Use query parameters in `CLICKHOUSE_DATABASE_URL` and `DATABASE_URL` instead.
- Remove `HOST` and `SCHEME` parameters in favor of a single `BASE_URL` parameter.
- Make `Bamboo.SMTPAdapter` the default as opposed to `Bamboo.PostmarkAdapter`
- Disable subscription flow by default
