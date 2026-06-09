import React, { ReactNode, useCallback } from 'react'

import {
  DimensionCellWithBar,
  DimensionCellWithBarProps,
  IndexBreakdown
} from '../reports/index-breakdown'
import { customPropsReportConfig } from '../reports/reports-config'
import { chooseBreakdownMetricsByContext } from '../breakdowns'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { externalLinkForPage } from '../../util/url'
import { IndexExternalLink } from '../pages/external-link'
import {
  EVENT_PROPS_PREFIX,
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { QueryApiResponse } from '../../api'

const BAR_COLOR = 'bg-red-50 group-hover/row:bg-red-100'

type SpecialGoalPropBreakdownProps = {
  prop: string
  afterFetchData?: (data: QueryApiResponse) => void
}

export function SpecialGoalPropBreakdown({
  prop,
  afterFetchData
}: SpecialGoalPropBreakdownProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportConfig = customPropsReportConfig(prop)

  const metrics = chooseBreakdownMetricsByContext(
    reportConfig.metricsByContext,
    {
      isRealtime: isRealTimeDashboard(dashboardState),
      isDetailed: false,
      hasConversionGoalFilter: hasConversionGoalFilter(dashboardState),
      isRevenueAvailable: false
    }
  )

  const DimensionElement = useCallback(
    (props: DimensionCellWithBarProps) => {
      const value = props.row.dimensions[0]
      const externalUrl = getExternalUrl(prop, value, site)
      return (
        <DimensionCellWithBar
          {...props}
          barClassName={BAR_COLOR}
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
      onDataReady={afterFetchData}
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
