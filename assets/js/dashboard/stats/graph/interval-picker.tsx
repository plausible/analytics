import React, { useRef } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import { isModifierPressed, isTyping, Keybind } from '../../keybinding'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext, PlausibleSite } from '../../site-context'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { BlurMenuButtonOnEscape, popover } from '../../components/popover'
import { DashboardState } from '../../dashboard-state'
import { Dayjs } from 'dayjs'
import { DashboardPeriod } from '../../dashboard-time-periods'

const INTERVAL_LABELS: Record<string, string> = {
  minute: 'Minutes',
  hour: 'Hours',
  day: 'Days',
  week: 'Weeks',
  month: 'Months'
}

function validIntervals(
  site: PlausibleSite,
  dashboardState: DashboardState
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

function getDefaultInterval(
  dashboardState: DashboardState,
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

export const getCurrentInterval = function (
  site: PlausibleSite,
  dashboardState: DashboardState
): string {
  const options = validIntervals(site, dashboardState)

  const storedInterval = getStoredInterval(dashboardState.period, site.domain)
  const defaultInterval = getDefaultInterval(dashboardState, options)

  if (storedInterval && options.includes(storedInterval)) {
    return storedInterval
  } else {
    return defaultInterval
  }
}

export function IntervalPicker({
  onIntervalUpdate
}: {
  onIntervalUpdate: (interval: string) => void
}): JSX.Element | null {
  const menuElement = useRef<HTMLButtonElement>(null)
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const dashboardRouteMatch = useMatch(rootRoute.path)

  if (dashboardState.period == 'realtime') {
    return null
  }

  const options = validIntervals(site, dashboardState)
  const currentInterval = getCurrentInterval(site, dashboardState)

  function updateInterval(interval: string): void {
    storeInterval(dashboardState.period, site.domain, interval)
    onIntervalUpdate(interval)
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
                {INTERVAL_LABELS[currentInterval]}
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
                      updateInterval(option)
                      closeDropdown()
                    }}
                    data-selected={option == currentInterval}
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
