import React, { useCallback } from 'react'
import Modal from '../modals/modal'
import { Metric } from '../metrics'
import * as url from '../../util/url'
import { StatsQuery } from '../../stats-query'
import { IndexBreakdown } from '../reports/index-breakdown'
import { DetailsBreakdown } from '../modals/details-breakdown'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { revenueAvailable, Filter } from '../../dashboard-state'
import { QueryApiResponse, QueryResultRow } from '../../api'
import { SortDirection } from '../../hooks/use-order-by'
import { addDimensionSearchFilter, getBreakdownMetrics } from '../breakdowns'
import { PAGES_BAR_COLOR } from './pages'

const DIMENSION = 'visit:entry_page'
const DETAILED_METRICS: Metric[] = [
  'visitors',
  'percentage',
  'visits',
  'bounce_rate',
  'visit_duration'
]

function getFilterInfo(row: QueryResultRow) {
  return {
    prefix: 'entry_page',
    filter: ['is', 'entry_page', [row.dimensions[0]]] as Filter
  }
}

function addSearchFilter(statsQuery: StatsQuery, search: string) {
  return addDimensionSearchFilter(statsQuery, DIMENSION, search)
}

export function EntryPagesIndex({
  afterFetchData
}: {
  afterFetchData?: (response: QueryApiResponse) => void
}) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const metrics = getBreakdownMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState)
  })

  const getExternalLinkUrl = useCallback(
    (row: QueryResultRow) => url.externalLinkForPage(site, row.dimensions[0]),
    [site]
  )

  return (
    <IndexBreakdown
      metrics={metrics}
      dimensions={[DIMENSION]}
      color={PAGES_BAR_COLOR}
      getExternalLinkUrl={getExternalLinkUrl}
      getFilterInfo={getFilterInfo}
      dimensionLabel="Entry page"
      afterFetchData={afterFetchData}
    />
  )
}

export function EntryPagesDetails() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const metrics = getBreakdownMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRealtime: isRealTimeDashboard(dashboardState),
    isDetailed: true,
    isRevenueAvailable: isRevenueAvailable,
    detailedMetrics: DETAILED_METRICS
  })

  const getExternalLinkUrl = useCallback(
    (row: QueryResultRow) => url.externalLinkForPage(site, row.dimensions[0]),
    [site]
  )

  return (
    <Modal>
      <DetailsBreakdown
        title="Entry pages"
        dimensionLabel="Entry page"
        dimensions={[DIMENSION]}
        metrics={metrics}
        defaultOrderBy={[['visitors', SortDirection.desc]]}
        getFilterInfo={getFilterInfo}
        getExternalLinkUrl={getExternalLinkUrl}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}
