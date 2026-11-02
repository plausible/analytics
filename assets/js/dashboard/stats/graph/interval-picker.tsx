import React, { useCallback, useEffect, useMemo, useState } from 'react'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { popover, SelectedCheckmark } from '../../components/popover'
import {
  Interval,
  GetIntervalProps,
  validIntervals,
  getDefaultInterval
} from './intervals'
import { PlausibleSite } from '../../site-context'
import { DashboardPeriod } from '../../dashboard-time-periods'

const INTERVAL_LABELS: Record<Interval, string> = {
  [Interval.minute]: 'Min',
  [Interval.hour]: 'Hours',
  [Interval.day]: 'Days',
  [Interval.week]: 'Weeks',
  [Interval.month]: 'Months'
}

function getIntervalStorageKey(
  domain: PlausibleSite['domain'],
  period: DashboardPeriod
) {
  return `interval__${period}__${domain}`
}

function getStoredInterval(
  domain: PlausibleSite['domain'],
  period: DashboardPeriod
): string | null {
  const stored = storage.getItem(getIntervalStorageKey(domain, period))

  if (stored === 'date') {
    return 'day'
  } else {
    return stored
  }
}

function storeInterval(
  domain: PlausibleSite['domain'],
  period: DashboardPeriod,
  interval: Interval
): void {
  storage.setItem(getIntervalStorageKey(domain, period), interval)
}

export const useStoredInterval = (
  props: Pick<PlausibleSite, 'domain'> & GetIntervalProps
) => {
  const { domain, period, from, to, comparison, compare_from, compare_to } =
    props

  // Dayjs objects are new references on every render, so we
  // use valueOf() (ms since epoch) to get stable primitive
  // values for dependency arrays.
  const customFrom = from?.valueOf()
  const customTo = to?.valueOf()
  const customComparisonFrom = compare_from?.valueOf()
  const customComparisonTo = compare_to?.valueOf()

  const { availableIntervals, storableIntervals } = useMemo(() => {
    return {
      availableIntervals: validIntervals(props),
      storableIntervals: validIntervals({ ...props, comparison: null })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    period,
    customFrom,
    customTo,
    comparison,
    customComparisonFrom,
    customComparisonTo
  ])

  const isValid = useCallback(
    (interval: string | null): interval is Interval =>
      !!interval && (availableIntervals as string[]).includes(interval),
    [availableIntervals]
  )

  // We skip storing interval selections that are only available
  // due to a custom comparison period. E.g. even though `month`
  // interval is available when comparing today with a whole year,
  // we shouldn't store `interval__day__site.com = month`.
  const isStorable = useCallback(
    (interval: string | null): interval is Interval =>
      !!interval && (storableIntervals as string[]).includes(interval),
    [storableIntervals]
  )

  const storedInterval = getStoredInterval(domain, period)

  const [selectedInterval, setSelectedInterval] = useState<string | null>(null)

  useEffect(() => {
    setSelectedInterval(null)
  }, [availableIntervals])

  const onIntervalClick = useCallback(
    (interval: Interval) => {
      if (isStorable(interval)) {
        storeInterval(domain, period, interval)
      }
      setSelectedInterval(interval)
    },
    [domain, period, isStorable]
  )

  return {
    selectedInterval: isValid(selectedInterval)
      ? selectedInterval
      : isValid(storedInterval)
        ? storedInterval
        : getDefaultInterval(props),
    onIntervalClick,
    availableIntervals
  }
}

export function IntervalPicker({
  selectedInterval,
  onIntervalClick,
  options
}: {
  selectedInterval: Interval
  onIntervalClick: (interval: Interval) => void
  options: Interval[]
}): JSX.Element | null {
  if (options.length === 0) {
    return null
  }

  return (
    <>
      <p className={popover.items.classNames.sectionTitle}>Graph interval</p>
      <div
        role="group"
        aria-label="Graph data interval"
        className="flex flex-col gap-y-0.5"
      >
        {options.map((value) => {
          const selected = value === selectedInterval
          return (
            <button
              key={value}
              type="button"
              data-testid={
                selected ? 'current-graph-interval' : 'graph-interval'
              }
              data-selected={selected}
              aria-pressed={selected}
              onClick={() => onIntervalClick(value)}
              className={classNames(
                popover.items.classNames.navigationLink,
                popover.items.classNames.selectedOption,
                popover.items.classNames.hoverLink
              )}
            >
              {INTERVAL_LABELS[value] ?? value}
              <SelectedCheckmark selected={selected} />
            </button>
          )
        })}
      </div>
    </>
  )
}
