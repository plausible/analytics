import React, { ReactNode, useMemo, useCallback } from 'react'

import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown,
  MIN_HEIGHT
} from '../reports/index-breakdown'
import { customPropsReportConfig } from '../reports/reports-config'
import { revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { hasConversionGoalFilter } from '../../util/filters'
import { QueryApiResponse } from '../../api'
import {
  BEHAVIOURS_BAR_COLOR,
  BEHAVIOURS_METRIC_COLUMN_WIDTH,
  BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE
} from '.'
import { makeGetCustomPropFilterInfo } from '../modals/props'

type PropertiesProps = {
  propKey: string | null
  onDataReady?: (data: QueryApiResponse) => void
}

export default function Properties({
  propKey,
  onDataReady
}: PropertiesProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportConfig = useMemo(
    () => (propKey ? customPropsReportConfig(propKey) : null),
    [propKey]
  )

  /*global BUILD_EXTRA*/
  const isRevenueAvailable =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  const metrics = useMemo(() => {
    if (!reportConfig) return []
    return reportConfig.getMetrics({
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable
    })
  }, [reportConfig, dashboardState, isRevenueAvailable])

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BEHAVIOURS_BAR_COLOR}
          text={props.row.dimensions[0]}
          getFilterInfo={makeGetCustomPropFilterInfo(propKey!)}
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
        onDataReady={onDataReady}
        bundlePercentageWithVisitors={false}
        metricColumnWidth={BEHAVIOURS_METRIC_COLUMN_WIDTH}
        hideMetricsOnMobile={BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE}
      />
    </div>
  )
}
