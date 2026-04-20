import React, { useCallback, useEffect, useMemo, useState } from 'react'
import * as storage from '../../util/storage'
import { SegmentedControl } from '../../components/segmented-control'
import {
  Interval,
  GetIntervalProps,
  validIntervals,
  getDefaultInterval
} from './intervals'

const INTERVAL_LABELS: Record<Interval, string> = {
  [Interval.minute]: 'Min',
  [Interval.hour]: 'Hours',
  [Interval.day]: 'Days',
  [Interval.week]: 'Weeks',
  [Interval.month]: 'Months'
}

function getStoredInterval(period: string, domain: string): string | null {
  const stored = storage.getItem(`interval__${period}__${domain}`)

  if (stored === 'date') {
    return 'day'
  } else {
    return stored
  }
}

function storeInterval(
  period: string,
  domain: string,
  interval: Interval
): void {
  storage.setItem(`interval__${period}__${domain}`, interval)
}

export const useStoredInterval = (props: GetIntervalProps) => {
  const { period, from, to, site, comparison, compare_from, compare_to } = props

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
    site,
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

  const storedInterval = getStoredInterval(period, site.domain)

  const [selectedInterval, setSelectedInterval] = useState<string | null>(null)

  useEffect(() => {
    setSelectedInterval(null)
  }, [availableIntervals])

  const onIntervalClick = useCallback(
    (interval: Interval) => {
      if (isStorable(interval)) {
        storeInterval(period, site.domain, interval)
      }
      setSelectedInterval(interval)
    },
    [period, site, isStorable]
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
