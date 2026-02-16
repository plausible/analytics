import React, { useCallback } from 'react'
import Modal from './modal'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { addFilter, revenueAvailable } from '../../dashboard-state'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SortDirection } from '../../hooks/use-order-by'

function PagesModal() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const reportInfo = {
    title: 'Top pages',
    dimension: 'page',
    endpoint: url.apiPath(site, '/pages'),
    dimensionLabel: 'Page url',
    defaultOrder: ['visitors', SortDirection.desc]
  }

  const getFilterInfo = useCallback(
    (listItem) => {
      return {
        prefix: reportInfo.dimension,
        filter: ['is', reportInfo.dimension, [listItem.name]]
      }
    },
    [reportInfo.dimension]
  )

  const addSearchFilter = useCallback(
    (dashboardState, searchString) => {
      return addFilter(dashboardState, [
        'contains',
        reportInfo.dimension,
        [searchString],
        { case_sensitive: false }
      ])
    },
    [reportInfo.dimension]
  )

  function chooseMetrics() {
    if (hasConversionGoalFilter(dashboardState)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({
          renderLabel: (_dashboardState) => 'Conversions',
          width: 'w-28'
        }),
        metrics.createConversionRate(),
        showRevenueMetrics && metrics.createTotalRevenue(),
        showRevenueMetrics && metrics.createAverageRevenue()
      ].filter((metric) => !!metric)
    }

    if (
      isRealTimeDashboard(dashboardState) &&
      !hasConversionGoalFilter(dashboardState)
    ) {
      return [
        metrics.createVisitors({
          renderLabel: (_dashboardState) => 'Current visitors',
          width: 'w-32'
        })
      ]
    }

    return [
      metrics.createVisitors({ renderLabel: (_dashboardState) => 'Visitors' }),
      metrics.createPageviews(),
      metrics.createBounceRate(),
      metrics.createTimeOnPage(),
      metrics.createScrollDepth()
    ]
  }

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default PagesModal
