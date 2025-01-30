/** @format */

import React, { useCallback, useEffect, useState } from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import {
  getSearchToApplyCustomDates,
  isComparisonEnabled
} from '../../query-time-periods'
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
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { useSiteContext } from '../../site-context'
import { formatISO, nowForSite } from '../../util/date'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const isComparing = isComparisonEnabled(query.comparison)
  const [calendar, setCalendar] = useState<
    | null
    | (Omit<DateRangeCalendarProps, 'id'> & { position: 'main' | 'compare' })
  >(null)
  const navigate = useAppNavigate()
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

  const mainCalendarProps: DateRangeCalendarProps = {
    id: 'calendar',
    onCloseWithSelection: (selection) =>
      navigate({
        search: getSearchToApplyCustomDates(selection)
      }),
    minDate: site.statsBegin,
    maxDate: formatISO(nowForSite(site)),
    defaultDates:
      query.from && query.to
        ? [formatISO(query.from), formatISO(query.to)]
        : undefined,
    onCloseWithNoSelection: () => setCalendar(null)
  }
  const openMainCalendar = useCallback(() => {
    setCalendar({ position: 'main' })
  }, [])

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows className={isComparing ? 'hidden md:flex' : ''} />
      <Popover className="min-w-36 md:relative lg:w-48">
        {({ close }) => (
          <>
            <QueryPeriodMenuButton />
            <QueryPeriodMenu
              closeDropdown={close}
              toggleCalendar={() => {
                if (calendar?.position === 'main') {
                  setCalendar(null)
                } else {
                  openMainCalendar()
                }
              }}
            />
          </>
        )}
      </Popover>
      <div className={calendarPositionClassName}>
        {calendar?.position === 'main' && (
          <DateRangeCalendar {...mainCalendarProps} />
        )}
      </div>
      {isComparing && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Popover className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <>
                <ComparisonPeriodMenuButton />
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
          <div className={calendarPositionClassName}>
            {calendar?.position === 'compare' && (
              <DateRangeCalendar id="calendar" {...calendar} />
            )}
          </div>
        </>
      )}
    </div>
  )
}

const calendarPositionClassName = classNames(
  'w-0 m-0 p-0 m-0 self-end md:relative', // 0px * 0px point of reference for calendar position
  '*:!top-auto *:!right-0 *:!absolute *:!mt-2' // positions calendar relative to the point
)
