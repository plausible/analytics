import React, { useCallback } from 'react'
import { useParams } from 'react-router-dom'

import Modal from './modal'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { addFilter, revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SortDirection } from '../../hooks/use-order-by'
import { SourceFavicon } from '../sources/source-favicon'

function ReferrerDrilldownModal() {
  const { referrer } = useParams()
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const reportInfo = {
    title: 'Referrer Drilldown',
    dimension: 'referrer',
    endpoint: url.apiPath(
      site,
      `/referrers/${url.maybeEncodeRouteParam(referrer)}`
    ),
    dimensionLabel: 'Referrer',
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
      metrics.createBounceRate(),
      metrics.createVisitDuration()
    ]
  }

  const renderIcon = useCallback((listItem) => {
    return (
      <SourceFavicon
        name={listItem.name}
        className="size-4 mr-2 align-middle inline"
      />
    )
  }, [])

  const getExternalLinkURL = useCallback((listItem) => {
    if (listItem.name !== 'Direct / None') {
      return '//' + listItem.name
    }
  }, [])

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        renderIcon={renderIcon}
        getExternalLinkURL={getExternalLinkURL}
      />
    </Modal>
  )
}

export default ReferrerDrilldownModal
