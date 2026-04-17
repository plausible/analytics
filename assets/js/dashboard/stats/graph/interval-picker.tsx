import React, { useCallback, useEffect, useRef, useState } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { BlurMenuButtonOnEscape, popover } from '../../components/popover'
import { DashboardState } from '../../dashboard-state'
import { ComparisonMode } from '../../dashboard-time-periods'
import {
  Interval,
  GetIntervalProps,
  validIntervals,
  getDefaultInterval
} from './intervals'

const INTERVAL_LABELS: Record<Interval, string> = {
  minute: 'Minutes',
  hour: 'Hours',
  day: 'Days',
  week: 'Weeks',
  month: 'Months'
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
