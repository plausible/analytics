import React, { useCallback, useEffect, useMemo, useState } from 'react'
import * as storage from '../../util/storage'
import { SegmentedControl } from '../../components/segmented-control'
import { PlausibleSite } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import { Dayjs } from 'dayjs'
import { DashboardPeriod } from '../../dashboard-time-periods'

const INTERVAL_LABELS: Record<string, string> = {
  minute: 'Min',
  hour: 'Hours',
  day: 'Days',
  week: 'Weeks',
  month: 'Months'
}

function validIntervals(
  site: Pick<PlausibleSite, 'validIntervalsByPeriod'>,
  dashboardState: Pick<DashboardState, 'period' | 'to' | 'from'>
): string[] {
  if (
    dashboardState.period === DashboardPeriod.custom &&
    dashboardState.from &&
    dashboardState.to
  ) {
    if (dashboardState.to.diff(dashboardState.from, 'days') < 7) {
      return ['day']
    } else if (dashboardState.to.diff(dashboardState.from, 'months') < 1) {
      return ['day', 'week']
    } else if (dashboardState.to.diff(dashboardState.from, 'months') < 12) {
      return ['day', 'week', 'month']
    } else {
      return ['week', 'month']
    }
  } else {
    return site.validIntervalsByPeriod[dashboardState.period]
  }
}

export function getDefaultInterval(
  dashboardState: Pick<DashboardState, 'period' | 'to' | 'from'>,
  validIntervals: string[]
): string {
  const defaultByPeriod: Record<string, string> = {
    day: 'hour',
    '24h': 'hour',
    '7d': 'day',
    '6mo': 'month',
    '12mo': 'month',
    year: 'month'
  }

  if (
    dashboardState.period === DashboardPeriod.custom &&
    dashboardState.from &&
    dashboardState.to
  ) {
    return defaultForCustomPeriod(dashboardState.from, dashboardState.to)
  } else {
    return defaultByPeriod[dashboardState.period] || validIntervals[0]
  }
}

function defaultForCustomPeriod(from: Dayjs, to: Dayjs): string {
  if (to.diff(from, 'days') < 30) {
    return 'day'
  } else if (to.diff(from, 'months') < 6) {
    return 'week'
  } else {
    return 'month'
  }
}

function getStoredInterval(period: string, domain: string): string | null {
  const stored = storage.getItem(`interval__${period}__${domain}`)

  if (stored === 'date') {
    return 'day'
  } else {
    return stored
  }
}

function storeInterval(period: string, domain: string, interval: string): void {
  storage.setItem(`interval__${period}__${domain}`, interval)
}

export const useStoredInterval = (
  site: PlausibleSite,
  { to, from, period }: Pick<DashboardState, 'to' | 'from' | 'period'>
) => {
  const availableIntervals = useMemo(
    () => validIntervals(site, { to, from, period }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [site, period, to?.valueOf() ?? null, from?.valueOf() ?? null]
  )

  const isValid = (interval: string | null): interval is string =>
    !!interval && availableIntervals.includes(interval)

  const storedInterval = getStoredInterval(period, site.domain)

  const [selectedInterval, setSelectedInterval] = useState<string | null>(null)

  useEffect(() => {
    setSelectedInterval(null)
  }, [availableIntervals])

  const onIntervalClick = useCallback(
    (interval: string) => {
      storeInterval(period, site.domain, interval)
      setSelectedInterval(interval)
    },
    [period, site.domain]
  )

  return {
    selectedInterval: isValid(selectedInterval)
      ? selectedInterval
      : isValid(storedInterval)
        ? storedInterval
        : getDefaultInterval({ to, from, period }, availableIntervals),
    onIntervalClick,
    availableIntervals
  }
}

export function IntervalPicker({
  selectedInterval,
  onIntervalClick,
  options
}: {
  selectedInterval: string
  onIntervalClick: (interval: string) => void
  options: string[]
}): JSX.Element | null {
  if (options.length === 0) {
    return null
  }

  const controlOptions = options.map((value) => ({
    value,
    label: INTERVAL_LABELS[value] ?? value
  }))

  return (
    <div className="flex justify-between items-center gap-x-2 w-full pl-4 pr-2 py-1">
      <span className="shrink-0 text-sm font-medium text-gray-700 dark:text-gray-100">
        Graph interval
      </span>
      <SegmentedControl
        ariaLabel="Graph data interval"
        options={controlOptions}
        selected={selectedInterval}
        onSelect={onIntervalClick}
        getTestId={(_value, isSelected) =>
          isSelected ? 'current-graph-interval' : 'graph-interval'
        }
      />
    </div>
  )
}
