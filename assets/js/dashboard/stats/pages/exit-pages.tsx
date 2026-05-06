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

const DIMENSION = 'visit:exit_page'
const DETAILED_METRICS: Metric[] = [
  'visitors',
  'percentage',
  'visits',
  'exit_rate'
]

function getFilterInfo(row: QueryResultRow) {
  return {
    prefix: 'exit_page',
    filter: ['is', 'exit_page', [row.dimensions[0]]] as Filter
  }
}

function addSearchFilter(statsQuery: StatsQuery, search: string) {
  return addDimensionSearchFilter(statsQuery, DIMENSION, search)
}

export function ExitPagesIndex({
  onDataReady
}: {
  onDataReady?: (data: QueryApiResponse) => void
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
      dimensionLabel="Exit page"
      onDataReady={onDataReady}
    />
  )
}

export function ExitPagesDetails() {
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
    detailedMetrics: [...DETAILED_METRICS]
  })

  const getExternalLinkUrl = useCallback(
    (row: QueryResultRow) => url.externalLinkForPage(site, row.dimensions[0]),
    [site]
  )

  return (
    <Modal>
      <DetailsBreakdown
        title="Exit pages"
        dimensionLabel="Exit page"
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
