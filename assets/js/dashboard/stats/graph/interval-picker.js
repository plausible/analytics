import React, { useRef } from 'react'
import {
  CloseButton,
  Popover,
  PopoverButton,
  PopoverPanel,
  Transition
} from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'
import {
  BlurMenuButtonOnEscape,
  isModifierPressed,
  isTyping,
  Keybind
} from '../../keybinding'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { popover } from '../../components/popover'

const INTERVAL_LABELS = {
  minute: 'Minutes',
  hour: 'Hours',
  day: 'Days',
  week: 'Weeks',
  month: 'Months'
}

function validIntervals(site, query) {
  if (query.period === 'custom') {
    if (query.to.diff(query.from, 'days') < 7) {
      return ['day']
    } else if (query.to.diff(query.from, 'months') < 1) {
      return ['day', 'week']
    } else if (query.to.diff(query.from, 'months') < 12) {
      return ['day', 'week', 'month']
    } else {
      return ['week', 'month']
    }
  } else {
    return site.validIntervalsByPeriod[query.period]
  }
}

function getDefaultInterval(query, validIntervals) {
  const defaultByPeriod = {
    day: 'hour',
    '7d': 'day',
    '6mo': 'month',
    '12mo': 'month',
    year: 'month'
  }

  if (query.period === 'custom') {
    return defaultForCustomPeriod(query.from, query.to)
  } else {
    return defaultByPeriod[query.period] || validIntervals[0]
  }
}

function defaultForCustomPeriod(from, to) {
  if (to.diff(from, 'days') < 30) {
    return 'day'
  } else if (to.diff(from, 'months') < 6) {
    return 'week'
  } else {
    return 'month'
  }
}

function getStoredInterval(period, domain) {
  const stored = storage.getItem(`interval__${period}__${domain}`)

  if (stored === 'date') {
    return 'day'
  } else {
    return stored
  }
}

function storeInterval(period, domain, interval) {
  storage.setItem(`interval__${period}__${domain}`, interval)
}

export const getCurrentInterval = function (site, query) {
  const options = validIntervals(site, query)

  const storedInterval = getStoredInterval(query.period, site.domain)
  const defaultInterval = getDefaultInterval(query, options)

  if (storedInterval && options.includes(storedInterval)) {
    return storedInterval
  } else {
    return defaultInterval
  }
}

export function IntervalPicker({ onIntervalUpdate }) {
  const menuElement = useRef(null)
  const { query } = useQueryContext()
  const site = useSiteContext()
  const dashboardRouteMatch = useMatch(rootRoute.path)

  if (query.period == 'realtime') return null

  const options = validIntervals(site, query)
  const currentInterval = getCurrentInterval(site, query)

  function updateInterval(interval) {
    storeInterval(query.period, site.domain, interval)
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
      <Popover className="relative inline-block pl-2">
        <BlurMenuButtonOnEscape targetRef={menuElement} />
        <PopoverButton
          ref={menuElement}
          className={classNames(
            popover.toggleButton.classNames.linkLike,
            'rounded-sm text-sm flex items-center'
          )}
        >
          {INTERVAL_LABELS[currentInterval]}
          <ChevronDownIcon className="ml-1 h-4 w-4" aria-hidden="true" />
        </PopoverButton>

        <Transition
          as="div"
          {...popover.transition.props}
          className={classNames(
            popover.transition.classNames.right,
            'mt-2 w-56'
          )}
        >
          <PopoverPanel className={classNames(popover.panel.classNames.roundedSheet, 'font-normal')}>
            {options.map((option) => (
              <CloseButton
                as="button"
                key={option}
                onClick={() => updateInterval(option)}
                data-selected={option == currentInterval}
                className={classNames(
                  popover.items.classNames.navigationLink,
                  popover.items.classNames.selectedOption,
                  popover.items.classNames.hoverLink,
                  popover.items.classNames.roundedStartEnd,
                  'w-full'
                )}
              >
                {INTERVAL_LABELS[option]}
              </CloseButton>
            ))}
          </PopoverPanel>
        </Transition>
      </Popover>
    </>
  )
}
