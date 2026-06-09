import React, { ReactNode, useMemo, useCallback } from 'react'

import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown,
  MIN_HEIGHT
} from '../reports/index-breakdown'
import { customPropsReportConfig } from '../reports/reports-config'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  EVENT_PROPS_PREFIX,
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { QueryApiResponse } from '../../api'

const BAR_COLOR = 'bg-red-50 group-hover/row:bg-red-100'

type PropertiesProps = {
  propKey: string | null
  afterFetchData?: (data: QueryApiResponse) => void
}

export default function Properties({
  propKey,
  afterFetchData
}: PropertiesProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const reportConfig = useMemo(
    () => (propKey ? customPropsReportConfig(propKey) : null),
    [propKey]
  )

  const metrics = useMemo(() => {
    if (!reportConfig) return []
    return chooseBreakdownMetricsByContext(reportConfig.metricsByContext, {
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: false,
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable
    })
  }, [reportConfig, dashboardState, isRevenueAvailable])

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      const value = props.row.dimensions[0]
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BAR_COLOR}
          text={value}
          getFilterInfo={() => ({
            prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
            filter: ['is', `${EVENT_PROPS_PREFIX}${propKey}`, [value]]
          })}
        />
      )
    },
    [propKey]
  )

  if (!propKey || !reportConfig) {
    return (
      <div className="flex-1 flex items-center justify-center font-medium text-gray-500 dark:text-gray-400">
        No custom properties found
      </div>
    )
  }

  return (
    <div className="w-full" style={{ minHeight: `${MIN_HEIGHT}px` }}>
      <IndexBreakdown
        metrics={metrics}
        dimensions={reportConfig.dimensions}
        dimensionLabel={reportConfig.dimensionLabel}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        DimensionElement={DimensionElement}
        onDataReady={afterFetchData}
      />
    </div>
  )
}
