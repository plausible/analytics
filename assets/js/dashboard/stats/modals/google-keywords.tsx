/** @format */

import React, { useMemo, useState } from 'react'

import Modal from './modal'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { usePaginatedGetAPI } from '../../hooks/api-client'
import { createVisitors, Metric } from '../reports/metrics'
import {
  numberShortFormatter,
  percentageFormatter
} from '../../util/number-formatter'
import { apiPath } from '../../util/url'
import { DashboardQuery } from '../../query'
import { ColumnConfiguration } from '../../components/table'
import { BreakdownTable } from './breakdown-table'

type GoogleKeywordItem = {
  visitors: string
  name: string
  impressions: number
  ctr: number
  position: number
}

const metrics = [
  createVisitors({ renderLabel: () => 'Visitors', sortable: false }),
  new Metric({
    width: 'w-28',
    key: 'impressions',
    renderLabel: () => 'Impressions',
    formatter: numberShortFormatter,
    sortable: false
  }),
  new Metric({
    width: 'w-16',
    key: 'ctr',
    renderLabel: () => 'CTR',
    formatter: percentageFormatter,
    sortable: false
  }),
  new Metric({
    width: 'w-28',
    key: 'position',
    renderLabel: () => 'Position',
    formatter: numberShortFormatter,
    sortable: false
  })
]

function GoogleKeywordsModal() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const endpoint = apiPath(site, '/referrers/Google')

  const [search, setSearch] = useState('')

  const apiState = usePaginatedGetAPI<
    { results: GoogleKeywordItem[] },
    [string, { query: DashboardQuery; search: string }]
  >({
    key: [endpoint, { query, search }],
    getRequestParams: (key) => {
      const [_endpoint, { query, search }] = key
      const params = { detailed: true }

      return [query, search === '' ? params : { ...params, search }]
    },
    initialPageParam: 0
  })

  const columns: ColumnConfiguration<GoogleKeywordItem>[] = useMemo(
    () => [
      {
        label: 'Search term',
        key: 'name',
        width: 'w-48 md:w-56 lg:w-1/3',
        align: 'left'
      },
      ...metrics.map(
        (m): ColumnConfiguration<GoogleKeywordItem> => ({
          label: m.renderLabel(query),
          key: m.key,
          width: m.width,
          align: 'right'
        })
      )
    ],
    [query]
  )

  return (
    <Modal>
      <BreakdownTable
        title="Google Search Terms"
        displayError={true}
        onSearch={setSearch}
        {...apiState}
        columns={columns}
      />
    </Modal>
  )
}

export default GoogleKeywordsModal
