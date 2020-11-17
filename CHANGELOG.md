# Changelog
All notable changes to this project will be documented in this file.

## [1.1.2] - Unreleased

### Added
- Ability to add event metadata plausible/analytics#381
- Add tracker module to automatically track outbound links  plausible/analytics#389
- Display weekday on the visitor graph plausible/analytics#175
- Collect and display browser & OS versions plausible/analytics#397

### Changed
- Use alpine as base image to decrease Docker image size plausible/analytics#353
- Ignore automated browsers (Phantom, Selenium, Headless Chrome, etc)
- Display domain's favicon on the home page

### Fixed
- Do not error when activating an already activated account plausible/analytics#370
- Ignore arrow keys when modifier keys are pressed plausible/analytics#363
- Show correct stats when goal filter is combined with source plausible/analytics#374
- Fix URL decoding in query parameters plausible/analytics#416

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
