/** @format */

import React, { useState, ReactNode, useMemo } from 'react'

import { useQueryContext } from '../../query-context'
import { usePaginatedGetAPI } from '../../hooks/api-client'
import { rootRoute } from '../../router'
import {
  getStoredOrderBy,
  Order,
  OrderBy,
  useOrderBy,
  useRememberOrderBy
} from '../../hooks/use-order-by'
import { Metric } from '../reports/metrics'
import { BreakdownResultMeta, DashboardQuery } from '../../query'
import { ColumnConfiguraton } from '../../components/table'
import { BreakdownTable } from './breakdown-table'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { DrilldownLink, FilterInfo } from '../../components/drilldown-link'
import { SharedReportProps } from '../reports/list'

export type ReportInfo = {
  /** Title of the report to render on the top left. */
  title: string
  /** Full pathname of the API endpoint to query. @example `/api/stats/plausible.io/sources` */
  endpoint: string
  /** Used as the leftmost column header. */
  dimensionLabel: string
  /** What this report will be initially sorted by. @example ["visitors", "desc"] */
  defaultOrder?: Order
}

type BreakdownModalProps<TListItem extends Record<string, unknown>> = Omit<
  SharedReportProps<TListItem>,
  'fetchData'
> & {
  /** Dimension and title of the breakdown. */
  reportInfo: ReportInfo
  /** Function that must return a new query that contains appropriate search filter for searchValue param. */
  addSearchFilter?: (q: DashboardQuery, searchValue: string) => DashboardQuery
  searchEnabled?: boolean
}

/**
  BreakdownModal is for rendering the "Details" reports on the dashboard,
  i.e. a breakdown by a single (non-time) dimension, with a given set of metrics.

  BreakdownModal is expected to be rendered inside a `<Modal>`, which has it's own
  specific URL pathname (e.g. /plausible.io/sources). During the lifecycle of a
  BreakdownModal, the `query` object is not expected to change.

  ### Search As You Type
  @see BreakdownTable

  ### Filter Links
  @see NameCell

  ### Pagination
  @see usePaginatedGetAPI

*/

export default function BreakdownModal<TListItem extends { name: string }>({
  reportInfo,
  metrics,
  renderIcon,
  getExternalLinkUrl,
  searchEnabled = true,
  afterFetchData,
  afterFetchNextPage,
  addSearchFilter,
  getFilterInfo
}: BreakdownModalProps<TListItem>) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const [meta, setMeta] = useState<BreakdownResultMeta | null>(null)

  const [search, setSearch] = useState('')
  const defaultOrderBy = getStoredOrderBy({
    domain: site.domain,
    reportInfo,
    metrics,
    fallbackValue: reportInfo.defaultOrder ? [reportInfo.defaultOrder] : []
  })
  const { orderBy, orderByDictionary, toggleSortByMetric } = useOrderBy({
    metrics,
    defaultOrderBy
  })
  useRememberOrderBy({
    effectiveOrderBy: orderBy,
    metrics,
    reportInfo
  })
  const apiState = usePaginatedGetAPI<
    { results: Array<TListItem>; meta: BreakdownResultMeta },
    [string, { query: DashboardQuery; search: string; orderBy: OrderBy }]
  >({
    key: [reportInfo.endpoint, { query, search, orderBy }],
    getRequestParams: (key) => {
      const [_endpoint, { query, search }] = key

      let queryWithSearchFilter = { ...query }

      if (
        searchEnabled &&
        typeof addSearchFilter === 'function' &&
        search !== ''
      ) {
        queryWithSearchFilter = addSearchFilter(query, search)
      }

      return [
        queryWithSearchFilter,
        {
          detailed: true,
          order_by: JSON.stringify(orderBy)
        }
      ]
    },
    afterFetchData: (response) => {
      setMeta(response.meta)
      afterFetchData?.(response)
    },
    afterFetchNextPage
  })

  const columns: ColumnConfiguraton<TListItem>[] = useMemo(
    () => [
      {
        label: reportInfo.dimensionLabel,
        key: 'name',
        width: 'w-48 md:w-full flex items-center break-all',
        align: 'left',
        renderItem: (item) => (
          <NameCell
            item={item}
            getFilterInfo={getFilterInfo}
            getExternalLinkUrl={getExternalLinkUrl}
            renderIcon={renderIcon}
          />
        )
      },
      ...metrics.map(
        (m): ColumnConfiguraton<TListItem> => ({
          label: m.renderLabel(query),
          key: m.key,
          width: m.width,
          align: 'right',
          metricWarning: getMetricWarning(m, meta, site),
          renderValue: (item) => m.renderValue(item, meta),
          onSort: m.sortable ? () => toggleSortByMetric(m) : undefined,
          sortDirection: orderByDictionary[m.key]
        })
      )
    ],
    [
      reportInfo.dimensionLabel,
      metrics,
      getFilterInfo,
      query,
      orderByDictionary,
      toggleSortByMetric,
      renderIcon,
      getExternalLinkUrl,
      meta,
      site
    ]
  )

  return (
    <BreakdownTable<TListItem>
      title={reportInfo.title}
      {...apiState}
      onSearch={searchEnabled ? setSearch : undefined}
      columns={columns}
    />
  )
}

/**
 * Most interactive cell in the breakdown table.
 * May have an icon.
 * If `getFilterInfo(item)` does not return null,
 * drills down the dashboard to that particular item.
 * May have a tiny icon button to navigate to the actual resource.
 * */
const NameCell = <TListItem extends { name: string }>({
  item,
  getFilterInfo,
  renderIcon,
  getExternalLinkUrl
}: {
  item: TListItem
  getFilterInfo: (item: TListItem) => FilterInfo | null
  renderIcon?: (item: TListItem) => ReactNode
  getExternalLinkUrl?: (listItem: TListItem) => string
}) => (
  <>
    {typeof renderIcon === 'function' && renderIcon(item)}
    <DrilldownLink
      path={rootRoute.path}
      filterInfo={getFilterInfo(item)}
      onClick={undefined}
      extraClass={undefined}
    >
      {item.name}
    </DrilldownLink>
    {typeof getExternalLinkUrl === 'function' && (
      <ExternalLinkIcon url={getExternalLinkUrl(item)} />
    )}
  </>
)

const ExternalLinkIcon = ({ url }: { url?: string }) =>
  url ? (
    <a
      target="_blank"
      href={url}
      rel="noreferrer"
      className="hidden group-hover:block"
    >
      <svg
        className="inline h-4 w-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400"
        fill="currentColor"
        viewBox="0 0 20 20"
      >
        <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path>
        <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path>
      </svg>
    </a>
  ) : null

const getMetricWarning = (
  metric: Metric,
  meta: BreakdownResultMeta | null,
  site: PlausibleSite
) => {
  const warnings = meta?.metric_warnings

  if (warnings && warnings[metric.key]) {
    const { code, message } = warnings[metric.key]

    if (metric.key == 'scroll_depth' && code == 'no_imported_scroll_depth') {
      return 'Does not include imported data'
    }

    if (metric.key == 'time_on_page' && code && site.flags.new_time_on_page) {
      return message
    }
  }
}
