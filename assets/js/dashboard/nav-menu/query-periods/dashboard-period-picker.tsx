import React, { useRef } from 'react'
import classNames from 'classnames'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { isComparisonEnabled } from '../../dashboard-time-periods'
import { MainCalendar, DashboardPeriodMenu } from './dashboard-period-menu'
import {
  ComparisonCalendarMenu,
  ComparisonPeriodMenu
} from './comparison-period-menu'
import { Popover } from '@headlessui/react'

export function DashboardPeriodPicker({ className }: { className?: string }) {
  const { dashboardState } = useDashboardStateContext()
  const isComparing = isComparisonEnabled(dashboardState.comparison)
  const mainCalendarButtonRef = useRef<HTMLButtonElement>(null)
  const compareCalendarButtonRef = useRef<HTMLButtonElement>(null)

  return (
    <div
      data-testid="query-period-picker"
      className={classNames('flex shrink-0', className)}
    >
      <Popover className="md:relative">
        {({ close }) => (
          <DashboardPeriodMenu
            closeDropdown={close}
            calendarButtonRef={mainCalendarButtonRef}
          />
        )}
      </Popover>
      <Popover className="w-0 h-8 md:relative">
        {({ close }) => (
          <MainCalendar
            calendarButtonRef={mainCalendarButtonRef}
            closeDropdown={close}
          />
        )}
      </Popover>
      {isComparing && (
        <>
          <div className="my-auto px-2.5 text-sm font-medium text-gray-800 dark:text-gray-200">
            vs
          </div>
          <Popover className="md:relative">
            {({ close }) => (
              <ComparisonPeriodMenu
                closeDropdown={close}
                calendarButtonRef={compareCalendarButtonRef}
              />
            )}
          </Popover>
          <Popover className="w-0 h-8 md:relative">
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
