import React, { HTMLAttributes } from 'react'
import { render, screen } from '@testing-library/react'
import { parseSiteFromDataset, PlausibleSite } from './site-context'

describe('parseSiteFromDataset', () => {
  const StatsReactContainer = ({
    ...attrs
  }: HTMLAttributes<HTMLDivElement>) => (
    <div
      data-testid="stats-react-container"
      data-domain="dummy.site/nice"
      data-offset="20700"
      data-has-goals="true"
      data-conversions-opted-out="false"
      data-funnels-opted-out="false"
      data-props-opted-out="false"
      data-funnels-available="true"
      data-site-segments-available="true"
      data-props-available="true"
      data-revenue-goals='[{"currency":"USD","display_name":"Purchase"}]'
      data-funnels='[{"id":1,"name":"From homepage to login","steps_count":3}]'
      data-has-props="true"
      data-scroll-depth-visible="true"
      data-logged-in="true"
      data-stats-begin="2021-09-07"
      data-native-stats-begin="2022-09-02"
      data-legacy-time-on-page-cutoff="2022-01-01T00:00:00Z"
      data-embedded=""
      data-is-dbip="false"
      data-current-user-role="owner"
      data-current-user-id="1"
      data-flags="{}"
      data-valid-intervals-by-period='{"12mo":["day","week","month"],"7d":["hour","day"],"28d":["day","week"],"30d":["day","week"],"90d":["day","week","month"],"6mo":["day","week","month"],"all":["week","month"],"custom":["day","week","month"],"day":["minute","hour"],"month":["day","week"],"realtime":["minute"],"year":["day","week","month"]}'
      {...attrs}
    />
  )
  const expectedParsedSite: PlausibleSite = {
    domain: 'dummy.site/nice',
    offset: 20700,
    hasGoals: true,
    conversionsOptedOut: false,
    funnelsOptedOut: false,
    propsOptedOut: false,
    funnelsAvailable: true,
    propsAvailable: true,
    siteSegmentsAvailable: true,
    revenueGoals: [{ currency: 'USD', display_name: 'Purchase' }],
    funnels: [{ id: 1, name: 'From homepage to login', steps_count: 3 }],
    hasProps: true,
    statsBegin: '2021-09-07',
    nativeStatsBegin: '2022-09-02',
    embedded: false,
    background: undefined,
    isDbip: false,
    flags: {},
    validIntervalsByPeriod: {
      '12mo': ['day', 'week', 'month'],
      '7d': ['hour', 'day'],
      '28d': ['day', 'week'],
      '30d': ['day', 'week'],
      '90d': ['day', 'week'],
      '6mo': ['day', 'week', 'month'],
      all: ['week', 'month'],
      custom: ['day', 'week', 'month'],
      day: ['minute', 'hour'],
      month: ['day', 'week'],
      realtime: ['minute'],
      year: ['day', 'week', 'month']
    },
    shared: false,
    legacyTimeOnPageCutoff: '2022-01-01T00:00:00Z'
  }

  it('parses from dom string map correctly', () => {
    render(<StatsReactContainer />)
    expect(
      parseSiteFromDataset(screen.getByTestId('stats-react-container').dataset)
    ).toEqual(expectedParsedSite)
  })

  it('handles embedded', () => {
    render(
      <StatsReactContainer
        data-embedded="true"
        data-logged-in="false"
        data-shared-link-auth="JO1Zc2Tg5gGJzOD2uae41"
        data-background="#foofoo"
      />
    )
    expect(
      parseSiteFromDataset(screen.getByTestId('stats-react-container').dataset)
    ).toEqual({
      ...expectedParsedSite,
      shared: true,
      embedded: true,
      background: '#foofoo'
    })
  })
})
