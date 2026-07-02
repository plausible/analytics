import { test, expect } from '@playwright/test'
import type { Page } from '@playwright/test'
import { unzipSync } from 'fflate'
import * as fs from 'fs'
import {
  setupSite,
  populateStats,
  addGoal,
  addCustomProp,
  StatsEntry
} from '../fixtures'

const EXPECTED_HEADERS = {
  defaultVisitorsCsv: [
    'date',
    'visitors',
    'pageviews',
    'visits',
    'views_per_visit',
    'bounce_rate',
    'visit_duration'
  ],
  pageFilteredVisitorsCsv: [
    'date',
    'visitors',
    'pageviews',
    'visits',
    'bounce_rate',
    'time_on_page',
    'scroll_depth'
  ],
  goalFilteredVisitorsCsv: [
    'date',
    'unique_conversions',
    'total_conversions',
    'conversion_rate'
  ],
  pagesBreakdown: [
    'name',
    'visitors',
    'pageviews',
    'bounce_rate',
    'time_on_page',
    'scroll_depth'
  ],
  entryPagesBreakdown: [
    'name',
    'unique_entrances',
    'total_entrances',
    'bounce_rate',
    'visit_duration'
  ],
  exitPagesBreakdown: ['name', 'unique_exits', 'total_exits', 'exit_rate'],
  exitPagesNoExitRate: ['name', 'unique_exits', 'total_exits'],
  commonBreakdown: ['name', 'visitors', 'bounce_rate', 'visit_duration'],
  commonGoalFilteredBreakdown: ['name', 'conversions', 'conversion_rate'],
  nameAndVisitors: ['name', 'visitors'],
  nameVersionAndVisitors: ['name', 'version', 'visitors'],
  nameVersionGoalFiltered: [
    'name',
    'version',
    'conversions',
    'conversion_rate'
  ],
  customPropsDefault: ['property', 'value', 'visitors', 'events', 'percentage'],
  customPropsGoalFiltered: [
    'property',
    'value',
    'visitors',
    'events',
    'conversion_rate'
  ],
  conversionsBreakdown: ['name', 'unique_conversions', 'total_conversions']
}

const UTM_AND_SOURCE_REPORTS = [
  'sources.csv',
  'channels.csv',
  'referrers.csv',
  'utm_mediums.csv',
  'utm_sources.csv',
  'utm_campaigns.csv',
  'utm_contents.csv',
  'utm_terms.csv'
]

const SIMPLE_LOCATION_AND_DEVICE_REPORTS = [
  'countries.csv',
  'regions.csv',
  'cities.csv',
  'browsers.csv',
  'operating_systems.csv',
  'devices.csv'
]

const VERSION_REPORTS = [
  'browser_versions.csv',
  'operating_system_versions.csv'
]

function parseAllCsvs(
  files: Record<string, string>
): Record<string, string[][]> {
  return Object.fromEntries(
    Object.entries(files).map(([filename, content]) => [
      filename,
      content
        .split(/\r?\n/)
        .filter((row) => !!row.length)
        .map((line) => line.split(','))
    ])
  )
}

function getCsv(
  csvs: Record<string, string[][]>,
  filename: string
): string[][] {
  const rows = csvs[filename]
  if (rows === undefined) throw new Error(`Expected ${filename} in CSV export`)
  return rows
}

test('csv export column headers match expected metrics for each report', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })
  await addCustomProp({ page, domain, name: 'author' })

  await populateStats({
    request,
    domain,
    events: [
      { name: 'pageview', 'meta.key': ['author'], 'meta.value': ['john'] },
      { name: 'Signup', 'meta.key': ['author'], 'meta.value': ['john'] }
    ]
  })

  await test.step('without any filters', async () => {
    await page.goto(`/${domain}?period=all`, {
      waitUntil: 'commit'
    })

    const csvs = parseAllCsvs(await triggerExportAndAwaitDownload(page))

    expect(getCsv(csvs, 'visitors.csv')[0]).toEqual(
      EXPECTED_HEADERS.defaultVisitorsCsv
    )
    expect(getCsv(csvs, 'pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.pagesBreakdown
    )
    expect(getCsv(csvs, 'entry_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.entryPagesBreakdown
    )
    expect(getCsv(csvs, 'exit_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.exitPagesBreakdown
    )

    for (const filename of UTM_AND_SOURCE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.commonBreakdown
      )
    }
    for (const filename of SIMPLE_LOCATION_AND_DEVICE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameAndVisitors
      )
    }
    for (const filename of VERSION_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameVersionAndVisitors
      )
    }
    expect(getCsv(csvs, 'custom_props.csv')[0]).toEqual(
      EXPECTED_HEADERS.customPropsDefault
    )
    expect(getCsv(csvs, 'conversions.csv')[0]).toEqual(
      EXPECTED_HEADERS.conversionsBreakdown
    )
  })

  await test.step('with a page filter', async () => {
    await page.goto(`/${domain}?period=all&f=is,page,/`, {
      waitUntil: 'commit'
    })

    await expect(
      page.getByRole('button', { name: 'Remove filter: Page is /' })
    ).toBeVisible()

    const csvs = parseAllCsvs(await triggerExportAndAwaitDownload(page))

    expect(getCsv(csvs, 'visitors.csv')[0]).toEqual(
      EXPECTED_HEADERS.pageFilteredVisitorsCsv
    )
    expect(getCsv(csvs, 'pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.pagesBreakdown
    )
    expect(getCsv(csvs, 'entry_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.entryPagesBreakdown
    )
    expect(getCsv(csvs, 'exit_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.exitPagesNoExitRate
    )

    for (const filename of UTM_AND_SOURCE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.commonBreakdown
      )
    }
    for (const filename of SIMPLE_LOCATION_AND_DEVICE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameAndVisitors
      )
    }
    for (const filename of VERSION_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameVersionAndVisitors
      )
    }
    expect(getCsv(csvs, 'custom_props.csv')[0]).toEqual(
      EXPECTED_HEADERS.customPropsDefault
    )
    expect(getCsv(csvs, 'conversions.csv')[0]).toEqual(
      EXPECTED_HEADERS.conversionsBreakdown
    )
  })

  await test.step('with a goal filter', async () => {
    await addGoal({ request, domain, params: { event_name: 'Signup' } })

    await page.goto(`/${domain}?period=all&f=is,goal,Signup`, {
      waitUntil: 'commit'
    })

    await expect(
      page.getByRole('button', { name: 'Remove filter: Goal is Signup' })
    ).toBeVisible()

    const csvs = parseAllCsvs(await triggerExportAndAwaitDownload(page))

    expect(getCsv(csvs, 'visitors.csv')[0]).toEqual(
      EXPECTED_HEADERS.goalFilteredVisitorsCsv
    )

    for (const filename of [
      'pages.csv',
      'entry_pages.csv',
      'exit_pages.csv',
      ...UTM_AND_SOURCE_REPORTS,
      ...SIMPLE_LOCATION_AND_DEVICE_REPORTS
    ]) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.commonGoalFilteredBreakdown
      )
    }
    for (const filename of VERSION_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameVersionGoalFiltered
      )
    }
    expect(getCsv(csvs, 'custom_props.csv')[0]).toEqual(
      EXPECTED_HEADERS.customPropsGoalFiltered
    )
    expect(getCsv(csvs, 'conversions.csv')[0]).toEqual(
      EXPECTED_HEADERS.conversionsBreakdown
    )
  })

  await test.step('with a custom prop filter', async () => {
    await page.goto(`/${domain}?period=all&f=is,props:author,john`, {
      waitUntil: 'commit'
    })

    await expect(
      page.getByRole('button', {
        name: 'Remove filter: Property author is john'
      })
    ).toBeVisible()

    const csvs = parseAllCsvs(await triggerExportAndAwaitDownload(page))

    expect(getCsv(csvs, 'visitors.csv')[0]).toEqual(
      EXPECTED_HEADERS.defaultVisitorsCsv
    )
    expect(getCsv(csvs, 'pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.pagesBreakdown
    )
    expect(getCsv(csvs, 'entry_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.entryPagesBreakdown
    )
    expect(getCsv(csvs, 'exit_pages.csv')[0]).toEqual(
      EXPECTED_HEADERS.exitPagesNoExitRate
    )

    for (const filename of UTM_AND_SOURCE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.commonBreakdown
      )
    }
    for (const filename of SIMPLE_LOCATION_AND_DEVICE_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameAndVisitors
      )
    }
    for (const filename of VERSION_REPORTS) {
      expect(getCsv(csvs, filename)[0]).toEqual(
        EXPECTED_HEADERS.nameVersionAndVisitors
      )
    }
    expect(getCsv(csvs, 'custom_props.csv')[0]).toEqual(
      EXPECTED_HEADERS.customPropsDefault
    )
    expect(getCsv(csvs, 'conversions.csv')[0]).toEqual(
      EXPECTED_HEADERS.conversionsBreakdown
    )
  })
})

test('filters out empty visit:* dimension values', async ({
  page,
  request
}) => {
  const { domain } = await setupSite({ page, request })

  const base: StatsEntry = {
    name: 'pageview',
    pathname: '/',
    timestamp: '2021-01-01 12:00:00',
    utm_medium: 't',
    utm_source: 't',
    utm_campaign: 't',
    utm_content: 't',
    utm_term: 't',
    country_code: 'EE',
    subdivision1_code: 'EE-37',
    city_geoname_id: 588_409
  }

  await populateStats({
    request,
    domain,
    events: [
      // session with empty entry page — excluded from entry_pages.csv
      { ...base, user_id: 1, pathname: '' },
      { ...base, user_id: 1, pathname: '/', timestamp: '2021-01-01 12:01:00' },
      // session with empty exit page — excluded from exit_pages.csv
      { ...base, user_id: 2, pathname: '/' },
      { ...base, user_id: 2, pathname: '', timestamp: '2021-01-01 12:01:00' },
      // one bad utm_* per session — each excluded from its own report
      { ...base, user_id: 3, utm_medium: '' },
      { ...base, user_id: 4, utm_source: '' },
      { ...base, user_id: 5, utm_campaign: '' },
      { ...base, user_id: 6, utm_content: '' },
      { ...base, user_id: 7, utm_term: '' },
      // one bad location per session — each excluded from its own report
      { ...base, user_id: 8, country_code: 'ZZ' },
      { ...base, user_id: 9, subdivision1_code: '' },
      { ...base, user_id: 10, city_geoname_id: 0 }
    ]
  })

  await page.goto(`/${domain}?period=all`, {
    waitUntil: 'commit'
  })

  const csvs = parseAllCsvs(await triggerExportAndAwaitDownload(page))

  // assert that each
  for (const filename of [
    'entry_pages.csv',
    'exit_pages.csv',
    'utm_mediums.csv',
    'utm_sources.csv',
    'utm_campaigns.csv',
    'utm_contents.csv',
    'utm_terms.csv',
    'countries.csv',
    'regions.csv',
    'cities.csv'
  ]) {
    await test.step(filename, async () => {
      expect(getCsv(csvs, filename).slice(1)).toHaveLength(1)
    })
  }
})

async function triggerExportAndAwaitDownload(
  page: Page
): Promise<Record<string, string>> {
  await page.getByTestId('dashboard-options-menu').click()
  await page.getByText('Export stats').waitFor({ state: 'visible' })

  const [result] = await Promise.all([
    Promise.race([
      page
        .waitForEvent('download')
        .then((d) => ({ ok: true as const, download: d })),
      page
        .waitForEvent('pageerror')
        .then((e) => ({ ok: false as const, error: e }))
    ]),
    page.getByText('Export stats').click()
  ])

  if (!result.ok) throw result.error
  const { download } = result

  const zipPath = await download.path()
  if (!zipPath) throw new Error('Download path unavailable')

  const files = unzipSync(new Uint8Array(fs.readFileSync(zipPath)))

  return Object.fromEntries(
    Object.entries(files).map(([filename, data]) => [
      filename,
      new TextDecoder().decode(data)
    ])
  )
}
