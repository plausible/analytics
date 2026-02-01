import React, { useRef } from 'react'
import classNames from 'classnames'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { isComparisonEnabled } from '../../dashboard-time-periods'
import { MovePeriodArrows } from './move-period-arrows'
import { MainCalendar, QueryPeriodMenu } from './query-period-menu'
import {
  ComparisonCalendarMenu,
  ComparisonPeriodMenu
} from './comparison-period-menu'
import { Popover } from '@headlessui/react'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const { dashboardState } = useDashboardStateContext()
  const isComparing = isComparisonEnabled(dashboardState.comparison)
  const mainCalendarButtonRef = useRef<HTMLButtonElement>(null)
  const compareCalendarButtonRef = useRef<HTMLButtonElement>(null)

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows className={isComparing ? 'hidden md:flex' : ''} />
      <Popover className="min-w-36 md:relative lg:w-48">
        {({ close }) => (
          <QueryPeriodMenu
            closeDropdown={close}
            calendarButtonRef={mainCalendarButtonRef}
          />
        )}
      </Popover>
      <Popover className="w-0 h-9 md:relative">
        {({ close }) => (
          <MainCalendar
            calendarButtonRef={mainCalendarButtonRef}
            closeDropdown={close}
          />
        )}
      </Popover>
      {isComparing && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="px-1">vs.</span>
          </div>
          <Popover className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <ComparisonPeriodMenu
                closeDropdown={close}
                calendarButtonRef={compareCalendarButtonRef}
              />
            )}
          </Popover>
          <Popover className="w-0 h-9 md:relative">
            {({ close }) => (
              <ComparisonCalendarMenu
                calendarButtonRef={compareCalendarButtonRef}
                closeDropdown={close}
              />
            )}
          </Popover>
        </>
      )}
    </div>
  )
}
