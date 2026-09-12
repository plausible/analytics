import React, { createContext, useContext } from 'react'
import { useStoredInterval } from './interval-picker'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { Interval } from './intervals'
import { useStoredSmoothing } from './smoothing-picker'
import { GraphSmoothing } from './smoothing'

type GraphIntervalContextValue = {
  selectedInterval: Interval
  onIntervalClick: (interval: Interval) => void
  availableIntervals: Interval[]
  selectedSmoothing: GraphSmoothing
  onSmoothingClick: (smoothing: GraphSmoothing) => void
}

const GraphIntervalContext = createContext<GraphIntervalContextValue | null>(
  null
)

export function GraphIntervalProvider({
  children
}: {
  children: React.ReactNode
}) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const { selectedSmoothing, onSmoothingClick } = useStoredSmoothing(
    site.domain
  )

  const { selectedInterval, onIntervalClick, availableIntervals } =
    useStoredInterval({
      domain: site.domain,
      siteTimezoneOffset: site.offset,
      siteStatsBegin: site.statsBegin,
      to: dashboardState.to,
      from: dashboardState.from,
      period: dashboardState.period,
      comparison: dashboardState.comparison,
      compare_to: dashboardState.compare_to,
      compare_from: dashboardState.compare_from
    })

  return (
    <GraphIntervalContext.Provider
      value={{
        selectedInterval,
        onIntervalClick,
        availableIntervals,
        selectedSmoothing,
        onSmoothingClick
      }}
    >
      {children}
    </GraphIntervalContext.Provider>
  )
}

export const useGraphIntervalContext = (): GraphIntervalContextValue =>
  useContext(GraphIntervalContext)!
