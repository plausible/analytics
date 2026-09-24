import React, { ReactNode, useCallback } from 'react'

import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown
} from '../reports/index-breakdown'
import { customPropsReportConfig } from '../reports/reports-config'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { externalLinkForPage } from '../../util/url'
import { IndexExternalLink } from '../pages/external-link'
import { EVENT_PROPS_PREFIX, hasConversionGoalFilter } from '../../util/filters'
import { QueryApiResponse } from '../../api'
import {
  BEHAVIOURS_BAR_COLOR,
  BEHAVIOURS_METRIC_COLUMN_WIDTH,
  BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE
} from '.'

type SpecialGoalPropBreakdownProps = {
  prop: string
  onDataReady?: (data: QueryApiResponse) => void
}

export function SpecialGoalPropBreakdown({
  prop,
  onDataReady
}: SpecialGoalPropBreakdownProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportConfig = customPropsReportConfig(prop)

  const metrics = reportConfig.getMetrics({
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
    isRevenueAvailable: false
  })

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      const value = props.row.dimensions[0]
      const externalUrl = getExternalUrl(prop, value, site)
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BEHAVIOURS_BAR_COLOR}
          text={value}
          externalLink={
            externalUrl && (
              <IndexExternalLink href={externalUrl} isActive={props.isActive} />
            )
          }
          getFilterInfo={() => ({
            prefix: `${EVENT_PROPS_PREFIX}${prop}`,
            filter: ['is', `${EVENT_PROPS_PREFIX}${prop}`, [value]]
          })}
        />
      )
    },
    [prop, site]
  )

  return (
    <IndexBreakdown
      metrics={metrics}
      dimensions={reportConfig.dimensions}
      dimensionLabel={reportConfig.dimensionLabel}
      alwaysOnFilters={reportConfig.alwaysOnFilters}
      DimensionElement={DimensionElement}
      onDataReady={onDataReady}
      metricColumnWidth={BEHAVIOURS_METRIC_COLUMN_WIDTH}
      hideMetricsOnMobile={BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE}
    />
  )
}

function getExternalUrl(
  prop: string,
  value: string,
  site: PlausibleSite
): string | null {
  if (prop === 'path') {
    return externalLinkForPage(site, value)
  }
  if (prop === 'search_query') {
    return null
  }
  return value
}
