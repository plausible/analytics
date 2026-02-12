import React, { useCallback } from 'react'
import { useParams } from 'react-router-dom'

import Modal from './modal'
import { addFilter, revenueAvailable } from '../../dashboard-state'
import { getSpecialGoal } from '../../util/goals'
import {
  EVENT_PROPS_PREFIX,
  getGoalFilter,
  hasConversionGoalFilter
} from '../../util/filters'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SortDirection } from '../../hooks/use-order-by'

function PropsModal() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const { propKey } = useParams()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const goalFilter = getGoalFilter(dashboardState)
  const specialGoal = goalFilter ? getSpecialGoal(goalFilter) : null

  const reportInfo = {
    title: specialGoal ? specialGoal.title : 'Custom property breakdown',
    dimension: propKey,
    endpoint: url.apiPath(
      site,
      `/custom-prop-values/${url.maybeEncodeRouteParam(propKey)}`
    ),
    dimensionLabel: propKey,
    defaultOrder: ['visitors', SortDirection.desc]
  }

  const getFilterInfo = useCallback(
    (listItem) => {
      return {
        prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
        filter: ['is', `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
      }
    },
    [propKey]
  )

  const addSearchFilter = useCallback(
    (dashboardState, searchString) => {
      return addFilter(dashboardState, [
        'contains',
        `${EVENT_PROPS_PREFIX}${propKey}`,
        [searchString],
        { case_sensitive: false }
      ])
    },
    [propKey]
  )

  function chooseMetrics() {
    return [
      metrics.createVisitors({ renderLabel: (_dashboardState) => 'Visitors' }),
      metrics.createEvents({ renderLabel: (_dashboardState) => 'Events' }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate(),
      !hasConversionGoalFilter(dashboardState) && metrics.createPercentage(),
      showRevenueMetrics && metrics.createAverageRevenue(),
      showRevenueMetrics && metrics.createTotalRevenue()
    ].filter((metric) => !!metric)
  }

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        showPercentageColumn
      />
    </Modal>
  )
}

export default PropsModal
