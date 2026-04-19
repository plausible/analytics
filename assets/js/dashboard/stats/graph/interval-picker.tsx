import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { BlurMenuButtonOnEscape, popover } from '../../components/popover'
import {
  Interval,
  GetIntervalProps,
  validIntervals,
  getDefaultInterval
} from './intervals'

const INTERVAL_LABELS: Record<Interval, string> = {
  [Interval.minute]: 'Minutes',
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
