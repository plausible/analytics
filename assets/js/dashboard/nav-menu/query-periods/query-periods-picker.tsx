/** @format */

import React, { useCallback, useEffect, useState } from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { isComparisonEnabled } from '../../query-time-periods'
import { MovePeriodArrows } from './move-period-arrows'
import { QueryPeriodMenu, QueryPeriodMenuButton } from './query-period-menu'
import {
  ComparisonPeriodMenuButton,
  ComparisonPeriodMenuItems
} from './comparison-period-menu'
import { Popover } from '@headlessui/react'
import {
  DateRangeCalendar,
  DateRangeCalendarProps
} from './date-range-calendar'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const { query } = useQueryContext()
  const isComparing = isComparisonEnabled(query.comparison)
  const [calendar, setCalendar] = useState<
    | null
    | (Omit<DateRangeCalendarProps, 'id'> & { position: 'main' | 'compare' })
  >(null)

  // const getShowCalendar = useCallback(
  //   (position: 'main' | 'compare') =>
  //     (
  //       props: Omit<DateRangeCalendarProps, 'id' | 'onCloseWithNoSelection'>
  //     ) => {
  //       setCalendar({
  //         ...props,
  //         position,
  //         onCloseWithNoSelection: () => setCalendar(null)
  //       })
  //     },
  //   []
  // )

  useEffect(() => {
    setCalendar(null)
  }, [query])

  useEffect(() => {
    console.log(calendar?.position)
  }, [calendar])

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows className={isComparing ? 'hidden md:flex' : ''} />
      <Popover className="min-w-36 md:relative lg:w-48">
        {({ close }) => (
          <>
            <QueryPeriodMenuButton />
            {calendar?.position === 'main' && (
              <DateRangeCalendar id="calendar" {...calendar} />
            )}
            <QueryPeriodMenu
              closeDropdown={close}
              showCalendar={(props) =>
                setCalendar({
                  ...props,
                  position: 'main',
                  onCloseWithNoSelection: () => setCalendar(null)
                })
              }
            />
          </>
        )}
      </Popover>
      {isComparing && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Popover className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <>
                <ComparisonPeriodMenuButton />
                {calendar?.position === 'compare' && (
                  <DateRangeCalendar id="calendar" {...calendar} />
                )}
                <ComparisonPeriodMenuItems
                  closeDropdown={close}
                  showCalendar={(props) =>
                    setCalendar({
                      ...props,
                      position: 'compare',
                      onCloseWithNoSelection: () => setCalendar(null)
                    })
                  }
                />
              </>
            )}
          </Popover>
        </>
      )}
    </div>
  )
}
