/** @format */

import React, { useEffect, useState } from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import {
  getSearchToApplyCustomComparisonDates,
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
import { DateRangeCalendar } from './date-range-calendar'
import { useAppNavigate } from '../../navigation/use-app-navigate'
import { useSiteContext } from '../../site-context'
import { formatISO, nowForSite } from '../../util/date'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const isComparing = isComparisonEnabled(query.comparison)
  const [calendar, setCalendar] = useState<null | 'main' | 'compare'>(null)
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
    console.log(calendar)
  }, [calendar])

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
                if (calendar === 'main') {
                  setCalendar(null)
                } else {
                  setCalendar('main')
                }
              }}
            />
          </>
        )}
      </Popover>
      <div className={calendarPositionClassName}>
        {calendar === 'main' && (
          <DateRangeCalendar
            id="calendar"
            onCloseWithSelection={(selection) =>
              navigate({
                search: getSearchToApplyCustomDates(selection)
              })
            }
            minDate={site.statsBegin}
            maxDate={formatISO(nowForSite(site))}
            defaultDates={
              query.from && query.to
                ? [formatISO(query.from), formatISO(query.to)]
                : undefined
            }
            onCloseWithNoSelection={() => setCalendar(null)}
          />
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
                  toggleCalendar={() => {
                    if (calendar === 'compare') {
                      setCalendar(null)
                    } else {
                      setCalendar('compare')
                    }
                  }}
                  // showCalendar={(props) =>
                  //   setCalendar({
                  //     ...props,
                  //     position: 'compare',
                  //     onCloseWithNoSelection: () => setCalendar(null)
                  //   })
                  // }
                />
              </>
            )}
          </Popover>
          <div className={calendarPositionClassName}>
            {calendar === 'compare' && (
              <DateRangeCalendar
                id="calendar"
                onCloseWithSelection={(selection) =>
                  navigate({
                    search: getSearchToApplyCustomComparisonDates(selection)
                  })
                }
                minDate={site.statsBegin}
                maxDate={formatISO(nowForSite(site))}
                defaultDates={
                  query.compare_from && query.compare_to
                    ? [
                        formatISO(query.compare_from),
                        formatISO(query.compare_to)
                      ]
                    : undefined
                }
                onCloseWithNoSelection={() => setCalendar(null)}
              />
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
