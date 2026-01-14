import React, { useCallback } from 'react'
import { useParams } from 'react-router-dom'

import Modal from './modal'
import { addFilter, revenueAvailable } from '../../query'
import { getSpecialGoal } from '../../util/goals'
import {
  EVENT_PROPS_PREFIX,
  getGoalFilter,
  hasConversionGoalFilter
} from '../../util/filters'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { SortDirection } from '../../hooks/use-order-by'

function PropsModal() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const { propKey } = useParams()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics = BUILD_EXTRA && revenueAvailable(query, site)

  const goalFilter = getGoalFilter(query)
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
    (query, searchString) => {
      return addFilter(query, [
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
      metrics.createVisitors({ renderLabel: (_query) => 'Visitors' }),
      metrics.createEvents({ renderLabel: (_query) => 'Events' }),
      hasConversionGoalFilter(query) && metrics.createConversionRate(),
      !hasConversionGoalFilter(query) && metrics.createPercentage(),
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
