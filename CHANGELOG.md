# Changelog
All notable changes to this project will be documented in this file.

## Unreleased

### Added
- Add top 3 pages into the traffic spike email
- Two new shorthand time periods `28d` and `90d` available on both dashboard and in public API
- Average scroll depth metric
- Scroll Depth goals
- Dashboard shows comparisons for all reports
- UTM Medium report and API shows (gclid) and (msclkid) for paid searches when no explicit utm medium present.
- Support for `case_sensitive: false` modifiers in Stats API V2 filters for case-insensitive searches.
- Add text version to emails plausible/analytics#4674
- Add acquisition channels report
- Add filter `is not` for goals in dashboard plausible/analytics#4983
- Add Segments feature
- Support `["is", "segment", [<segment ID>]]` filter in Stats API
- Time on page metric is now sortable in reports
- Plausible tracker script now reports maximum scroll depth reached and time engaged with the site in an `engagement` event. These are reported as `sd` and `e` integer parameters to /api/event endpoint respectively. If you're using a custom proxy for plausible script, please ensure that these parameters are being passed forward.
- Plausible tracker script now reports the version of the script in the `v` parameter sent with each request.
- Add support for creating and managing teams owning multiple sites
- Introduce "billing" team role for users
- Introduce "editor" role with permissions greater than "viewer" but lesser than "admin"

### Removed

- Internal stats API routes no longer support legacy dashboard filter format.
- Dashboard no longer shows "Unique visitors" in top stats when filtering by a goal which used to count all users including ones who didn't complete the goal. "Unique conversions" shows the number of unique visitors who completed the goal.

### Changed

- Increase decimal precision of the "Conversion rate" metric from 1 to 2 (e.g. 16.7 -> 16.67)
- The "Last 30 days" period is now "Last 28 days" on the dashboard and also the new default. Keyboard shortcut `T` still works for last 30 days.
- Last `7d` and `30d` periods do not include today anymore
- Filters appear in the search bar as ?f=is,page,/docs,/blog&f=... instead of ?filters=((is,page,(/docs,/blog)),...) for Plausible links sent on various platforms to work reliably.
- Details modal search inputs are now case-insensitive.
- Improved report performance in cases where site has a lot of unique pathnames
- Plausible script now uses `fetch` with keepalive flag as default over `XMLHttpRequest`. This will ensure more reliable tracking. Reminder to use `compat` script variant if tracking Internet Explorer is required.
- The old `/api/health` healtcheck is soft-deprecated in favour of separate `/api/system/health/live` and `/api/system/health/ready` checks
- Changed top bar filter menu and how applied filters wrap
- Main graph now shows revenue with relevant currency symbol when hovering a data point
- Main graph now shows `-` instead of `0` for visit duration, scroll depth when hovering a data point with no visit data
- Make Stats and Sites API keys scoped to teams they are created in

### Fixed

- Fix fetching favicons from DuckDuckGo when the domain includes a pathname
- Fix `visitors.csv` (in dashboard CSV export) vs dashboard main graph reporting different results for `visitors` and `visits` with a `time:minute` interval.
- The tracker script now sends pageviews when a page gets loaded from bfcache
- Fix returning filter suggestions for multiple custom property values in the dashboard Filter modal
- Fix typo on login screen
- Fix Direct / None details modal not opening
- Fix year over year comparisons being offset by a day for leap years
- Breakdown modals now display correct comparison values instead of 0 after pagination
- Fix database mismatch between event and session user_ids after rotating salts
- `/api/v2/query` no longer returns a 500 when querying percentage metric without `visitors`
- Fix current visitors loading when viewing a dashboard with a shared link
- Fix Conversion Rate graph being unselectable when "Goal is ..." filter is within a segment
- Fix Channels filter input appearing when clicking Sources in filter menu or clicking an applied "Channel is..." filter
- Fix Conversion Rate metrics column disappearing from reports when "Goal is ..." filter is within a segment
- Graph tooltip now shows year when graph has data from multiple years

## v2.1.5-rc.1 - 2025-01-17

### Added

- Add text version to emails https://github.com/plausible/analytics/pull/4674
- Add error logging when email delivery fails https://github.com/plausible/analytics/pull/4885

### Removed

- Remove Plausible Cloud contacts https://github.com/plausible/analytics/pull/4766
- Remove trial mentions https://github.com/plausible/analytics/pull/4668
- Remove billings and upgrade tabs from settings https://github.com/plausible/analytics/pull/4897

## v2.1.4 - 2024-10-08

### Added

- Add ability to review and revoke particular logged in user sessions
- Add ability to change password from user settings screen
- Add error logs for background jobs plausible/analytics#4657

### Changed

- Revised User Settings UI
- Default to `invite_only` for registration plausible/analytics#4616

### Fixed

- Fix cross-device file move in CSV exports/imports plausible/analytics#4640

## v2.1.3 - 2024-09-26

### Fixed
- Change cookie key to resolve login issue plausible/analytics#4621
- Set secure attribute on cookies when BASE_URL has HTTPS scheme plausible/analytics#4623
- Don't track custom events in CE plausible/analytics#4627

## v2.1.2 - 2024-09-24

### Added
- UI to edit goals along with display names
- Support contains filter for goals
- UI to edit funnels
- Add Details views for browsers, browser versions, os-s, os versions, and screen sizes reports
- Add a search functionality in all Details views
- Icons for browsers plausible/analytics#4239
- Automatic custom property selection in the dashboard Properties report
- Add `contains_not` filter support to dashboard
- Traffic drop notifications plausible/analytics#4300
- Add search and pagination functionality into Google Keywords > Details modal
- ClickHouse system.query_log table log_comment column now contains information about source of queries. Useful for debugging
- New /debug/clickhouse route for super admins which shows information on clickhouse queries executed by user
- Typescript support for `/assets`
- Testing framework for `/assets`
- Automatic HTTPS plausible/analytics#4491
- Make details views on dashboard sortable

### Removed
- Deprecate `ECTO_IPV6` and `ECTO_CH_IPV6` env vars in CE plausible/analytics#4245
- Remove support for importing data from no longer available Universal Analytics
- Soft-deprecate `DATABASE_SOCKET_DIR` plausible/analytics#4202

### Changed
- Support Unix sockets in `DATABASE_URL` plausible/analytics#4202
- Realtime and hourly graphs now show visits lasting their whole duration instead when specific events occur
- Increase hourly request limit for API keys in CE from 600 to 1000000 (practically removing the limit) plausible/analytics#4200
- Make TCP connections try IPv6 first with IPv4 fallback in CE plausible/analytics#4245
- `is` and `is not` filters in dashboard no longer support wildcards. Use contains/does not contain filter instead.
- `bounce_rate` metric now returns 0 instead of null for event:page breakdown when page has never been entry page.
- Make `TOTP_VAULT_KEY` optional plausible/analytics#4317
- Sources like 'google' and 'facebook' are now stored in capitalized forms ('Google', 'Facebook') plausible/analytics#4417
- `DATABASE_CACERTFILE` now forces TLS for PostgreSQL connections, so you don't need to add `?ssl=true` in `DATABASE_URL`
- Change auth session cookies to token-based ones with server-side expiration management.
- Improve Google error messages in CE plausible/analytics#4485
- Better compress static assets in CE plausible/analytics#4476
- Return domain-less cookies in CE plausible/analytics#4482
- Internal stats API routes now return a JSON error over HTML in case of invalid access.

### Fixed

- Fix access to Stats API feature in CE plausible/analytics#4244
- Fix filter suggestions when same filter previously applied
- Fix MX lookup when using relays with Bamboo.Mua plausible/analytics#4350
- Don't include imports when showing time series hourly interval. Previously imported data was shown each midnight
- Fix property filter suggestions 500 error when property hasn't been selected
- Bamboo.Mua: add Date and Message-ID headers if missing plausible/analytics#4474
- Fix migration order across `plausible_db` and `plausible_events_db` databases plausible/analytics#4466
- Fix tooltips for countries/cities/regions links in dashboard

## v2.1.1 - 2024-06-06

### Added

- Snippet integration verification
- Limited filtering support for imported data in the dashboard and via Stats API
- Automatic sites.imported_data -> site_imports data migration in CE plausible/analytics#4155

### Fixed

- Fix CSV import by adding a newline to the INSERT statement plausible/analytics#4172
- Fix url parameters escaping of = sign plausible/analytics#4185
- Fix redirect after registration in CE plausible/analytics#4165
- Fix VersionedSessions migration in ClickHouse v24 plausible/analytics#4162

## v2.1.0 - 2024-05-23

### Added
- Hostname Allow List in Site Settings
- Pages Block List in Site Settings
- Add `conversion_rate` to Stats API Timeseries and on the main graph
- Add `total_conversions` and `conversion_rate` to `visitors.csv` in a goal-filtered CSV export
- Ability to display total conversions (with a goal filter) on the main graph
- Add `conversion_rate` to Stats API Timeseries and on the main graph
- Add `time_on_page` metric into the Stats API
- County Block List in Site Settings
- Query the `views_per_visit` metric based on imported data as well if possible
- Group `operating_system_versions` by `operating_system` in Stats API breakdown
- Add `operating_system_versions.csv` into the CSV export
- Display `Total visitors`, `Conversions`, and `CR` in the "Details" views of Countries, Regions and Cities (when filtering by a goal)
- Add `conversion_rate` to Regions and Cities reports (when filtering by a goal)
- Add the `conversion_rate` metric to Stats API Breakdown and Aggregate endpoints
- IP Block List in Site Settings
- Allow filtering with `contains`/`matches` operator for Sources, Browsers and Operating Systems.
- Allow filtering by multiple custom properties
- Wildcard and member filtering on the Stats API `event:goal` property
- Allow filtering with `contains`/`matches` operator for custom properties
- Add `referrers.csv` to CSV export
- Add a new Properties section in the dashboard to break down by custom properties
- Add `custom_props.csv` to CSV export (almost the same as the old `prop_breakdown.csv`, but has different column headers, and includes props for pageviews too, not only custom events)
- Add `referrers.csv` to CSV export
- Improve password validation in registration and password reset forms
- Adds Gravatar profile image to navbar
- Enforce email reverification on update
- Add Plugins API Tokens provisioning UI
- Add searching sites by domain in /sites view
- Add last 24h plots to /sites view
- Add site pinning to /sites view
- Add support for JSON logger, via LOG_FORMAT=json environment variable
- Add support for 2FA authentication
- Add 'browser_versions.csv' to CSV export
- Add `CLICKHOUSE_MAX_BUFFER_SIZE_BYTES` env var which defaults to `100000` (100KB)
- Add alternative SMTP adapter plausible/analytics#3654
- Add `EXTRA_CONFIG_PATH` env var to specify extra Elixir config plausible/analytics#3906
- Add restrictive `robots.txt` for self-hosted plausible/analytics#3905
- Add Yesterday as an time range option in the dashboard
- Add dmg extension to the list of default tracked file downloads
- Add support for importing Google Analytics 4 data
- Import custom events from Google Analytics 4
- Ability to filter Search Console keywords by page, country and device plausible/analytics#4077
- Add `DATA_DIR` env var for exports/imports plausible/analytics#4100
- Add custom events support to CSV export and import

### Removed
- Removed the nested custom event property breakdown UI when filtering by a goal in Goal Conversions
- Removed the `prop_names` returned in the Stats API `event:goal` breakdown response
- Removed the `prop-breakdown.csv` file from CSV export
- Deprecated `CLICKHOUSE_MAX_BUFFER_SIZE`
- Removed `/app/init-admin.sh` that was deprecated in v2.0.0 plausible/analytics#3903
- Remove `DISABLE_AUTH` deprecation warning plausible/analytics#3904

### Changed
- A visits `entry_page` and `exit_page` is only set and updated for pageviews, not custom events
- Limit the number of Goal Conversions shown on the dashboard and render a "Details" link when there are more entries to show
- Show Outbound Links / File Downloads / 404 Pages / Cloaked Links instead of Goal Conversions when filtering by the corresponding goal
- Require custom properties to be explicitly added from Site Settings > Custom Properties in order for them to show up on the dashboard
- GA/SC sections moved to new settings: Integrations
- Replace `CLICKHOUSE_MAX_BUFFER_SIZE` with `CLICKHOUSE_MAX_BUFFER_SIZE_BYTES`
- Validate metric isn't queried multiple times
- Filters in dashboard are represented by jsonurl
- `MAILER_EMAIL` now defaults to an address built off of `BASE_URL` plausible/analytics#4538
- default `MAILER_ADAPTER` has been changed to `Bamboo.Mua` plausible/analytics#4538

### Fixed
- Creating many sites no longer leads to cookie overflow
- Ignore sessions without pageviews for `entry_page` and `exit_page` breakdowns
- Using `VersionedCollapsingMergeTree` to store visit data to avoid rare race conditions that led to wrong visit data being shown
- Fix `conversion_rate` metric in a `browser_versions` breakdown
- Calculate `conversion_rate` percentage change in the same way like `bounce_rate` (subtraction instead of division)
- Calculate `bounce_rate` percentage change in the Stats API in the same way as it's done in the dashboard
- Stop returning custom events in goal breakdown with a pageview goal filter and vice versa
- Only return `(none)` values in custom property breakdown for the first page (pagination) of results
- Fixed weekly/monthly e-mail report [rendering issues](https://github.com/plausible/analytics/issues/284)
- Fix [broken interval selection](https://github.com/plausible/analytics/issues/2982) in the all time view plausible/analytics#3110
- Fixed [IPv6 problems](https://github.com/plausible/analytics/issues/3173) in data migration plausible/analytics#3179
- Fixed [long URLs display](https://github.com/plausible/analytics/issues/3158) in Outbound Link breakdown view
- Fixed [Sentry reports](https://github.com/plausible/analytics/discussions/3166) for ingestion requests plausible/analytics#3182
- Fix breakdown pagination bug in the dashboard details view when filtering by goals
- Update bot detection (matomo 6.1.4, ua_inspector 3.4.0)
- Improved the Goal Settings page (search, autcompletion etc.)
- Log mailer errors plausible/analytics#3336
- Allow custom event timeseries in stats API plausible/analytics#3505
- Fixes for sites with UTF characters in domain plausible/analytics#3560
- Fix crash when using special characters in filter plausible/analytics#3634
- Fix automatic scrolling to the bottom on the dashboard if previously selected properties tab plausible/analytics#3872
- Allow running the container with arbitrary UID plausible/analytics#2986
- Fix `width=manual` in embedded dashboards plausible/analytics#3910
- Fix URL escaping when pipes are used in UTM tags plausible/analytics#3930

## v2.0.0 - 2023-07-12

### Added
- Call to action for tracking Goal Conversions and an option to hide the section from the dashboard
- Add support for `with_imported=true` in Stats API aggregate endpoint
- Ability to use '--' instead of '=' sign in the `tagged-events` classnames
- 'Last updated X seconds ago' info to 'current visitors' tooltips
- Add support for more Bamboo adapters, i.e. `Bamboo.MailgunAdapter`, `Bamboo.MandrillAdapter`, `Bamboo.SendGridAdapter` plausible/analytics#2649
- Ability to change domain for existing site (requires numeric IDs data migration, instructions will be provided separately) UI + API (`PUT /api/v1/sites`)
- Add `LOG_FAILED_LOGIN_ATTEMPTS` environment variable to enable failed login attempts logs plausible/analytics#2936
- Add `MAILER_NAME` environment variable support plausible/analytics#2937
- Add `MAILGUN_BASE_URI` support for `Bamboo.MailgunAdapter` plausible/analytics#2935
- Add a landing page for self-hosters plausible/analytics#2989
- Allow optional IPv6 for clickhouse repo plausible/analytics#2970

### Fixed
- Fix tracker bug - call callback function even when event is ignored
- Make goal-filtered CSV export return only unique_conversions timeseries in the 'visitors.csv' file
- Stop treating page filter as an entry page filter
- City report showing N/A instead of city names with imported data plausible/analytics#2675
- Empty values for Screen Size, OS and Browser are uniformly replaced with "(not set)"
- Fix [more pageviews with session prop filter than with no filters](https://github.com/plausible/analytics/issues/1666)
- Cascade delete sent_renewal_notifications table when user is deleted plausible/analytics#2549
- Show appropriate top-stat metric labels on the realtime dashboard when filtering by a goal
- Fix breakdown API pagination when using event metrics plausible/analytics#2562
- Automatically update all visible dashboard reports in the realtime view
- Connect via TLS when using HTTPS scheme in ClickHouse URL plausible/analytics#2570
- Add error message in case a transfer to an invited (but not joined) user is requested plausible/analytics#2651
- Fix bug with [showing property breakdown with a prop filter](https://github.com/plausible/analytics/issues/1789)
- Fix bug when combining goal and prop filters plausible/analytics#2654
- Fix broken favicons when domain includes a slash
- Fix bug when using multiple [wildcard goal filters](https://github.com/plausible/analytics/pull/3015)
- Fix a bug where realtime would fail with imported data
- Fix a bug where the country name was not shown when [filtering through the map](https://github.com/plausible/analytics/issues/3086)

### Changed
- Treat page filter as entry page filter for `bounce_rate`
- Reject events with long URIs and data URIs plausible/analytics#2536
- Always show direct traffic in sources reports plausible/analytics#2531
- Stop recording XX and T1 country codes plausible/analytics#2556
- Device type is now determined from the User-Agent instead of window.innerWidth plausible/analytics#2711
- Add padding by default to embedded dashboards so that shadows are not cut off plausible/analytics#2744
- Update the User Agents database (https://github.com/matomo-org/device-detector/releases/tag/6.1.1)
- Disable registration in self-hosted setups by default plausible/analytics#3014

### Removed
- Remove Firewall plug and `IP_BLOCKLIST` environment variable
- Remove the ability to collapse the main graph plausible/analytics#2627
- Remove `custom_dimension_filter` feature flag plausible/analytics#2996

## v1.5.1 - 2022-12-06

### Fixed
- Return empty list when breaking down by event:page without events plausible/analytics#2530
- Fallback to empty build metadata when failing to parse $BUILD_METADATA plausible/analytics#2503

## v1.5.0 - 2022-12-02

### Added
- Set a different interval on the top graph plausible/analytics#1574 (thanks to @Vigasaurus for this feature)
- A `tagged-events` script extension for out-of-the-box custom event tracking
- The ability to escape `|` characters with `\` in Stats API filter values
- An upper bound of 1000 to the `limit` parameter in Stats API
- The `exclusions` script extension now also takes a `data-include` attribute tag
- A `file-downloads` script extension for automatically tracking file downloads as custom events
- Integration with [Matomo's referrer spam list](https://github.com/matomo-org/referrer-spam-list/blob/master/spammers.txt) to block known spammers
- API route `PUT /api/v1/sites/goals` with form params `site_id`, `event_name` and/or `page_path`, and `goal_type` with supported types `event` and `page`
- API route `DELETE /api/v1/sites/goals/:goal_id` with form params `site_id`
- The public breakdown endpoint can be queried with the "events" metric
- Data exported via the download button will contain CSV data for all visible graps in a zip file.
- Region and city-level geolocation plausible/analytics#1449
- The `u` option can now be used in the `manual` extension to specify a URL when triggering events.
- Delete a site and all related data through the Sites API
- Subscribed users can see their Paddle invoices from the last 12 months under the user settings
- Allow custom styles to be passed to embedded iframe plausible/analytics#1522
- New UTM Tags `utm_content` and `utm_term` plausible/analytics#515
- If a session was started without a screen_size it is updated if an event with screen_size occurs
- Added `LISTEN_IP` configuration parameter plausible/analytics#1189
- The breakdown endpoint with the property query `property=event:goal` returns custom goal properties (within `props`)
- Added IPv6 Ecto support (via the environment-variable `ECTO_IPV6`)
- New filter type: `contains`, available for `page`, `entry_page`, `exit_page`
- Add filter for custom property
- Add ability to import historical data from GA: plausible/analytics#1753
- API route `GET /api/v1/sites/:site_id`
- Hovering on top of list items will now show a [tooltip with the exact number instead of a shortened version](https://github.com/plausible/analytics/discussions/1968)
- Filter goals in realtime filter by clicking goal name
- The time format (12 hour or 24 hour) for graph timelines is now presented based on the browser's defined language
- Choice of metric for main-graph both in UI and API (visitors, pageviews, bounce_rate, visit_duration) plausible/analytics#1364
- New width=manual mode for embedded dashboards plausible/analytics#2148
- Add more timezone options
- Add new strategy to recommend timezone when creating a new site
- Alert outgrown enterprise users of their usage plausible/analytics#2197
- Manually lock and unlock enterprise users plausible/analytics#2197
- ARM64 support for docker images plausible/analytics#2103
- Add support for international domain names (IDNs) plausible/analytics#2034
- Allow self-hosters to register an account on first launch
- Fix ownership transfer invitation link in self-hosted deployments

### Fixed
- Plausible script does not prevent default if it's been prevented by an external script [plausible/analytics#1941](https://github.com/plausible/analytics/issues/1941)
- Hash part of the URL can now be used when excluding pages with `script.exclusions.hash.js`.
- UI fix where multi-line text in pills would not be underlined properly on small screens.
- UI fix to align footer columns
- Guests can now use the favicon to toggle additional info about the site bing viewed (such as in public embeds).
- Fix SecurityError in tracking script when user has blocked all local storage
- Prevent dashboard graph from being selected when long pressing on the graph in a mobile browser
- The exported `pages.csv` file now includes pageviews again [plausible/analytics#1878](https://github.com/plausible/analytics/issues/1878)
- Fix a bug where city, region and country filters were filtering stats but not the location list
- Fix a bug where regions were not being saved
- Timezone offset labels now update with time changes
- Render 404 if shared link auth cannot be verified [plausible/analytics#2225](https://github.com/plausible/analytics/pull/2225)
- Restore compatibility with older format of shared links [plausible/analytics#2225](https://github.com/plausible/analytics/pull/2225)
- Fix 'All time' period for sites with no recorded stats [plausible/analytics#2277](https://github.com/plausible/analytics/pull/2277)
- Ensure settings page can be rendered after a form error [plausible/analytics#2278](https://github.com/plausible/analytics/pull/2278)
- Ensure newlines from settings files are trimmed [plausible/analytics#2480](https://github.com/plausible/analytics/pull/2480)

### Changed
- `script.file-downloads.outbound-links.js` only sends an outbound link event when an outbound download link is clicked
- Plausible script now uses callback navigation (instead of waiting for 150ms every time) when sending custom events
- Cache the tracking script for 24 hours
- Move `entry_page` and `exit_page` to be part of the `Page` filter group
- Paginate /api/sites results and add a `View all` link to the site-switcher dropdown in the dashboard.
- Remove the `+ Add Site` link to the site-switcher dropdown in the dashboard.
- `DISABLE_REGISTRATIONS` configuration parameter can now accept `invite_only` to allow invited users to register an account while keeping regular registrations disabled plausible/analytics#1841
- New and improved Session tracking module for higher throughput and lower latency. [PR#1934](https://github.com/plausible/analytics#1934)
- Do not display ZZ country code in countries report [PR#1934](https://github.com/plausible/analytics#2223)
- Add fallback icon for when DDG favicon cannot be fetched [PR#2279](https://github.com/plausible/analytics#2279)

### Security
- Add Content-Security-Policy header to favicon path

## v1.4.1 - 2021-11-29

### Fixed
- Fixes database error when pathname contains a question mark

## v1.4.0 - 2021-10-27

### Added
- New parameter `metrics` for the `/api/v1/stats/timeseries` endpoint plausible/analytics#952
- CSV export now includes pageviews, bounce rate and visit duration in addition to visitors plausible/analytics#952
- Send stats to multiple dashboards by configuring a comma-separated list of domains plausible/analytics#968
- To authenticate against a local postgresql via socket authentication, the environment-variables
  `DATABASE_SOCKET_DIR` & `DATABASE_NAME` were added.
- Time on Page metric available in detailed Top Pages report plausible/analytics#1007
- Wildcard based page, entry page and exit page filters plausible/analytics#1067
- Exclusion filters for page, entry page and exit page filters plausible/analytics#1067
- Menu (with auto-complete) to add new and edit existing filters directly plausible/analytics#1089
- Added `CLICKHOUSE_FLUSH_INTERVAL_MS` and `CLICKHOUSE_MAX_BUFFER_SIZE` configuration parameters plausible/analytics#1073
- Ability to invite users to sites with different roles plausible/analytics#1122
- Option to configure a custom name for the script file
- Add Conversion Rate to Top Sources, Top Pages Devices, Countries when filtered by a goal plausible/analytics#1299
- Add list view for countries report in dashboard plausible/analytics#1381
- Add ability to view more than 100 custom goal properties plausible/analytics#1382

### Fixed
- Fix weekly report time range plausible/analytics#951
- Make sure embedded dashboards can run when user has blocked third-party cookies plausible/analytics#971
- Sites listing page will paginate if the user has a lot of sites plausible/analytics#994
- Crash when changing theme on a loaded dashboard plausible/analytics#1123
- UI fix for details button overlapping content on mobile plausible/analytics#1114
- UI fix for the main graph on mobile overlapping its tick items on both axis
- UI fixes for text not showing properly in bars across multiple lines. This hides the totals on <768px and only shows the uniques and % to accommodate the goals text too. Larger screens still truncate as usual.
- Turn off autocomplete for name and password inputs in the _New shared link_ form.
- Details modals are now responsive and take up less horizontal space on smaller screens to make it easier to scroll.
- Fix reading config from file
- Fix some links not opening correctly in new tab
- UI fix for more than one row of custom event properties plausible/analytics#1383
- UI fix for user menu and time picker overlapping plausible/analytics#1352
- Respect the `path` component of BASE_URL to allow subfolder installatons

### Removed
- Removes AppSignal monitoring package

### Changes
- Disable email verification by default. Added a configuration option `ENABLE_EMAIL_VERIFICATION=true` if you want to keep the old behaviour

## [1.3] - 2021-04-14

### Added
- Stats API [currently in beta] plausible/analytics#679
- Ability to view and filter by entry and exit pages, in addition to regular page hits plausible/analytics#712
- 30 day and 6 month keybindings (`T` and `S`, respectively) plausible/analytics#709
- Site switching keybinds (1-9 for respective sites) plausible/analytics#735
- Glob (wildcard) based pageview goals plausible/analytics#750
- Support for embedding shared links in an iframe plausible/analytics#812
- Include a basic IP-To-Country database by default plausible/analytics#906
- Add name/label to shared links plausible/analytics#910

### Fixed
- Capitalized date/time selection keybinds not working plausible/analytics#709
- Invisible text on Google Search Console settings page in dark mode plausible/analytics#759
- Disable analytics tracking when running Cypress tests
- CSV reports can be downloaded via shared links plausible/analytics#884
- Fixes weekly/monthly email report delivery over SMTP plausible/analytics#889
- Disable self-tracking with self hosting plausible/analytics#907
- Fix current visitors request when using shared links

## [1.2] - 2021-01-26

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
- Tracking exclusions, see our documentation [here](https://docs.plausible.io/excluding) and [here](https://docs.plausible.io/excluding-pages) for details plausible/analytics#489
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
