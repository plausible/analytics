import React, { useCallback } from 'react'
import Modal from '../modals/modal'
import { Metric } from '../metrics'
import * as url from '../../util/url'
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
import { getBreakdownMetrics } from '../breakdowns'

export const PAGES_BAR_COLOR = 'bg-orange-50 group-hover/row:bg-orange-100'

const DIMENSION = 'event:page'
const DETAILED_METRICS: Metric[] = [
  'visitors',
  'percentage',
  'pageviews',
  'bounce_rate',
  'time_on_page',
  'scroll_depth'
]

function getFilterInfo(row: QueryResultRow) {
  return {
    prefix: 'page',
    filter: ['is', 'page', [row.dimensions[0]]] as Filter
  }
}

export function PagesIndex({
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
      dimensionLabel="Page"
      onDataReady={onDataReady}
    />
  )
}

export function PagesDetails() {
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
        title="Top pages"
        dimensionLabel="Page url"
        dimensions={[DIMENSION]}
        metrics={metrics}
        defaultOrderBy={[['visitors', 'desc']]}
        getFilterInfo={getFilterInfo}
        getExternalLinkUrl={getExternalLinkUrl}
      />
    </Modal>
  )
}
