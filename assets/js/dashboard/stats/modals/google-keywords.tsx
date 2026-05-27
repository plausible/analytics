import React, { useMemo, useState } from 'react'

import Modal from './modal'
import {
  numberShortFormatter,
  percentageFormatter
} from '../../util/number-formatter'
import { ColumnConfiguration } from '../breakdowns'
import { BreakdownTable } from './breakdown-table'
import {
  SearchTermsResultItem,
  useDetailedGoogleSearchTermsQuery
} from '../sources/fetch-search-terms'

const metricColumns = [
  {
    key: 'visitors',
    label: 'Visitors',
    formatter: numberShortFormatter,
    width: 'w-28'
  },
  {
    key: 'impressions',
    label: 'Impressions',
    formatter: numberShortFormatter,
    width: 'w-28'
  },
  { key: 'ctr', label: 'CTR', formatter: percentageFormatter, width: 'w-24' },
  {
    key: 'position',
    label: 'Position',
    formatter: numberShortFormatter,
    width: 'w-24'
  }
]

function GoogleKeywordsModal() {
  const [search, setSearch] = useState('')

  const apiState = useDetailedGoogleSearchTermsQuery({ search })

  const columns: ColumnConfiguration<SearchTermsResultItem>[] = useMemo(
    () => [
      {
        key: 'name',
        renderLabel: () => 'Search term',
        renderCell: (item) => item.name,
        width: 'w-48 max-w-48 md:w-56 md:max-w-56',
        align: 'left'
      },

      ...metricColumns.map((m): ColumnConfiguration<SearchTermsResultItem> => {
        const metric = m.key as keyof SearchTermsResultItem

        return {
          key: metric,
          renderLabel: () => m.label,
          renderCell: (item) => item[metric],
          width: m.width,
          align: 'right'
        }
      })
    ],
    []
  )

  const tableData = apiState.data
    ? { pages: apiState.data.pages.map((p) => p.results) }
    : undefined

  return (
    <Modal>
      <BreakdownTable<SearchTermsResultItem>
        title="Google search terms"
        onSearch={setSearch}
        {...apiState}
        error={apiState.error}
        data={tableData}
        columns={columns}
        getRowKey={(row: SearchTermsResultItem) => row.name}
      />
    </Modal>
  )
}

export default GoogleKeywordsModal
