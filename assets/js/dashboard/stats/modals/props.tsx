import React, { useCallback } from 'react'
import { useParams } from 'react-router-dom'

import Modal from './modal'
import {
  DetailsBreakdown,
  DimensionCell,
  DimensionCellProps
} from './details-breakdown'
import { customPropsReportConfig } from '../reports/reports-config'
import { revenueAvailable } from '../../dashboard-state'
import { getSpecialGoal } from '../../util/goals'
import {
  EVENT_PROPS_PREFIX,
  getGoalFilter,
  hasConversionGoalFilter
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { QueryResultRow } from '../../api'
import { NonTimeDimension } from '../../stats-query'
import { FilterInfo } from '../../components/drilldown-link'

function PropsModal() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const { propKey } = useParams<{ propKey: string }>()

  const DimensionElementForProp = useCallback(
    (props: DimensionCellProps) => (
      <DimensionCell
        {...props}
        text={props.row.dimensions[0]}
        getFilterInfo={makeGetCustomPropFilterInfo(propKey!)}
      />
    ),
    [propKey]
  )

  if (!propKey) {
    return null
  }

  const goalFilter = getGoalFilter(dashboardState)
  const specialGoal = goalFilter ? getSpecialGoal(goalFilter) : null

  const reportConfig = customPropsReportConfig(propKey)

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site) && !specialGoal

  const metrics = reportConfig.getMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRevenueAvailable
  })

  const title = specialGoal ? specialGoal.title : 'Custom property breakdown'

  return (
    <Modal>
      <DetailsBreakdown
        title={title}
        dimensionLabel={reportConfig.dimensionLabel}
        dimensions={reportConfig.dimensions}
        metrics={metrics}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        defaultOrderBy={[['visitors', 'desc']]}
        DimensionElement={DimensionElementForProp}
        bundlePercentageWithVisitors={false}
      />
    </Modal>
  )
}

export function makeGetCustomPropFilterInfo(propKey: string) {
  const filterKey = `${EVENT_PROPS_PREFIX}${propKey}`
  return (_dimension: NonTimeDimension, row: QueryResultRow): FilterInfo => ({
    prefix: filterKey,
    filter: ['is', filterKey, [row.dimensions[0]]]
  })
}

export default PropsModal
