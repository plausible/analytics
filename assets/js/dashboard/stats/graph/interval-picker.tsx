import React, { useCallback, useEffect, useRef, useState } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { PlausibleSite } from '../../site-context'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { BlurMenuButtonOnEscape, popover } from '../../components/popover'
import { DashboardState } from '../../dashboard-state'
import { Dayjs } from 'dayjs'
import { ComparisonMode, DashboardPeriod } from '../../dashboard-time-periods'
import { dateForSite, nowForSite } from '../../util/date'

type Interval = 'minute' | 'hour' | 'day' | 'week' | 'month'

type GetIntervalProps = { site: PlausibleSite } & Pick<
  DashboardState,
  'period' | 'to' | 'from' | 'comparison' | 'compare_to' | 'compare_from'
>

type DayjsRange = { from: Dayjs; to: Dayjs }

type FixedPeriod = Exclude<DashboardPeriod, 'custom' | 'all'>

const INTERVAL_LABELS: Record<Interval, string> = {
  minute: 'Minutes',
  hour: 'Hours',
  day: 'Days',
  week: 'Weeks',
  month: 'Months'
}

const VALID_INTERVALS_BY_FIXED_PERIOD: Record<FixedPeriod, Interval[]> = {
  realtime: ['minute'],
  realtime_30m: ['minute'],
  day: ['minute', 'hour'],
  '24h': ['minute', 'hour'],
  '7d': ['hour', 'day'],
  '28d': ['day', 'week'],
  '30d': ['day', 'week'],
  '91d': ['day', 'week', 'month'],
  month: ['day', 'week'],
  '6mo': ['day', 'week', 'month'],
  '12mo': ['day', 'week', 'month'],
  year: ['day', 'week', 'month']
}

const INTERVAL_COARSENESS: Record<Interval, number> = {
  minute: 0,
  hour: 1,
  day: 2,
  week: 3,
  month: 4
}

function max_coarseness(intervals: Interval[]): number {
  return Math.max(...intervals.map((i) => INTERVAL_COARSENESS[i]))
}

function coarser(a: Interval[], b: Interval[]): Interval[] {
  return max_coarseness(a) >= max_coarseness(b) ? a : b
}

function validIntervalsForMainPeriod(
  site: PlausibleSite,
  period: DashboardPeriod,
  from: Dayjs | null,
  to: Dayjs | null
): Interval[] {
  if (period === DashboardPeriod.custom && from && to) {
    return validIntervalsForCustomPeriod({ from, to })
  }
  if (period === 'all') {
    return validIntervalsForAllTimePeriod(site)
  }
  return VALID_INTERVALS_BY_FIXED_PERIOD[period as FixedPeriod]
}

function validIntervalsForCustomComparison(
  comparison: ComparisonMode | null,
  compare_from: Dayjs | null,
  compare_to: Dayjs | null
): Interval[] | null {
  if (comparison === ComparisonMode.custom && compare_from && compare_to) {
    return validIntervalsForCustomPeriod({ from: compare_from, to: compare_to })
  }
  return null
}

export function validIntervals({
  site,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval[] {
  const mainIntervals = validIntervalsForMainPeriod(site, period, from, to)
  const comparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )
  return comparisonIntervals
    ? coarser(mainIntervals, comparisonIntervals)
    : mainIntervals
}

export function getDefaultInterval({
  site,
  period,
  to,
  from,
  comparison,
  compare_to,
  compare_from
}: GetIntervalProps): Interval {
  const mainIntervals = validIntervalsForMainPeriod(site, period, from, to)
  const comparisonIntervals = validIntervalsForCustomComparison(
    comparison,
    compare_from,
    compare_to
  )

  if (
    comparisonIntervals &&
    max_coarseness(comparisonIntervals) > max_coarseness(mainIntervals)
  ) {
    return defaultForCustomPeriod({ from: compare_from!, to: compare_to! })
  }

  if (period === DashboardPeriod.custom && from && to) {
    return defaultForCustomPeriod({ from, to })
  }

  if (period === 'all') {
    return mainIntervals.includes('day') ? 'day' : 'month'
  }

  switch (period) {
    case 'day':
      return 'hour'
    case '24h':
      return 'hour'
    case '7d':
      return 'day'
    case '6mo':
      return 'month'
    case '12mo':
      return 'month'
    case 'year':
      return 'month'
    default:
      return VALID_INTERVALS_BY_FIXED_PERIOD[period as FixedPeriod][0]
  }
}

function validIntervalsForCustomPeriod({ to, from }: DayjsRange): Interval[] {
  if (to.diff(from, 'days') < 7) {
    return ['day']
  }
  if (to.diff(from, 'months') < 1) {
    return ['day', 'week']
  }
  if (to.diff(from, 'months') < 12) {
    return ['day', 'week', 'month']
  }
  return ['week', 'month']
}

function validIntervalsForAllTimePeriod(site: PlausibleSite): Interval[] {
  const to = nowForSite(site)
  const from = site.statsBegin ? dateForSite(site.statsBegin, site) : to

  return validIntervalsForCustomPeriod({ from, to })
}

function defaultForCustomPeriod({ from, to }: DayjsRange): Interval {
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

function storeInterval(
  period: string,
  domain: string,
  interval: Interval,
  comparison: DashboardState['comparison']
): void {
  // Skip storing interval selections when in custom comparison mode
  // as it affects the set of valid intervals.
  if (comparison !== ComparisonMode.custom) {
    storage.setItem(`interval__${period}__${domain}`, interval)
  }
}

export const useStoredInterval = (props: GetIntervalProps) => {
  const { period, site, comparison } = props
  const availableIntervals = validIntervals(props)

  const isValid = (interval: string | null): interval is Interval =>
    !!interval && (availableIntervals as string[]).includes(interval)

  const storedInterval = getStoredInterval(period, site.domain)

  const [selectedInterval, setSelectedInterval] = useState<string | null>(null)

  // Dayjs objects are new references on every render, so
  // we use valueOf() (ms since epoch) to get stable
  // primitive values for the effect dependency array.
  const customFrom = props.from?.valueOf()
  const customTo = props.to?.valueOf()
  const customComparisonFrom = props.compare_from?.valueOf()
  const customComparisonTo = props.compare_to?.valueOf()

  useEffect(() => {
    setSelectedInterval(null)
  }, [
    period,
    customFrom,
    customTo,
    comparison,
    customComparisonFrom,
    customComparisonTo
  ])

  const onIntervalClick = useCallback(
    (interval: Interval) => {
      storeInterval(period, site.domain, interval, comparison)
      setSelectedInterval(interval)
    },
    [period, site.domain, comparison]
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
  const menuElement = useRef<HTMLButtonElement>(null)
  const { dashboardState } = useDashboardStateContext()
  const dashboardRouteMatch = useMatch(rootRoute.path)

  if (dashboardState.period == 'realtime') {
    return null
  }

  return (
    <>
      {!!dashboardRouteMatch && (
        <Keybind
          targetRef="document"
          type="keydown"
          keyboardKey="i"
          handler={() => {
            menuElement.current?.click()
          }}
          shouldIgnoreWhen={[isModifierPressed, isTyping]}
        />
      )}
      <Popover className="relative inline-block">
        {({ close: closeDropdown }) => (
          <>
            <BlurMenuButtonOnEscape targetRef={menuElement} />
            <Popover.Button
              ref={menuElement}
              className={classNames(
                popover.toggleButton.classNames.linkLike,
                'rounded-sm text-sm flex items-center'
              )}
            >
              <span data-testid="current-graph-interval">
                {INTERVAL_LABELS[selectedInterval]}
              </span>
              <ChevronDownIcon className="ml-1 h-4 w-4" aria-hidden="true" />
            </Popover.Button>

            <Transition
              as="div"
              {...popover.transition.props}
              className={classNames(
                popover.transition.classNames.right,
                'mt-2 w-56'
              )}
            >
              <Popover.Panel
                className={classNames(
                  popover.panel.classNames.roundedSheet,
                  'font-normal'
                )}
              >
                {options.map((option) => (
                  <button
                    key={option}
                    onClick={() => {
                      onIntervalClick(option)
                      closeDropdown()
                    }}
                    data-selected={option == selectedInterval}
                    className={classNames(
                      popover.items.classNames.navigationLink,
                      popover.items.classNames.selectedOption,
                      popover.items.classNames.hoverLink,
                      'w-full text-left'
                    )}
                  >
                    <span data-testid="graph-interval">
                      {INTERVAL_LABELS[option]}
                    </span>
                  </button>
                ))}
              </Popover.Panel>
            </Transition>
          </>
        )}
      </Popover>
    </>
  )
}
