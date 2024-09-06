/** @format */

import React, { useMemo, useState } from 'react'

import Modal from './modal'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { usePaginatedGetAPI } from '../../hooks/api-client'
import {
  createVisitors,
  Metric,
  renderNumberWithTooltip
} from '../reports/metrics'
import numberFormatter, {
  percentageFormatter
} from '../../util/number-formatter'
import { apiPath } from '../../util/url'
import { DashboardQuery } from '../../query'
import { ColumnConfiguraton } from '../../components/table'
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
    renderValue: renderNumberWithTooltip,
    sortable: false
  }),
  new Metric({
    width: 'w-16',
    key: 'ctr',
    renderLabel: () => 'CTR',
    renderValue: percentageFormatter,
    sortable: false
  }),
  new Metric({
    width: 'w-28',
    key: 'position',
    renderLabel: () => 'Position',
    renderValue: numberFormatter,
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

  const columns: ColumnConfiguraton<GoogleKeywordItem>[] = useMemo(
    () => [
      {
        label: 'Search term',
        key: 'name',
        accessor: 'name',
        width: 'w-48 md:w-56 lg:w-1/3',
        align: 'left'
      },
      ...metrics.map(
        (m): ColumnConfiguraton<GoogleKeywordItem> => ({
          label: m.renderLabel(query),
          key: m.key,
          accessor: m.accessor,
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
