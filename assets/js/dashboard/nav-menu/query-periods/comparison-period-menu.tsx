/** @format */

import React, { useState, useEffect, useRef, useCallback } from 'react'
import { formatDateRange, formatISO, nowForSite } from '../../util/date'
import { clearedComparisonSearch } from '../../query'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { BlurMenuButtonOnEscape } from '../../keybinding'
import {
  AppNavigationLink,
  useAppNavigate
} from '../../navigation/use-app-navigate'
import { DateRangeCalendar } from './date-range-calendar'
import {
  COMPARISON_MODES,
  ComparisonMode,
  isComparisonEnabled,
  getSearchToApplyCustomComparisonDates,
  COMPARISON_MATCH_MODE_LABELS,
  ComparisonMatchMode
} from '../../query-time-periods'
import { Menu, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  datemenuButtonClassName,
  DateMenuChevron,
  linkClassName,
  MenuSeparator
} from './shared-menu-items'

export const ComparisonPeriodMenuItems = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()
  const [menuVisible, setMenuVisible] = useState<boolean>(false)

  const closeMenu = useCallback(() => {
    setMenuVisible(false)
  }, [])

  useEffect(() => {
    closeMenu()
  }, [closeMenu, query])

  if (!isComparisonEnabled(query.comparison)) {
    return null
  }
  return (
    <>
      {menuVisible && (
        <DateRangeCalendar
          id="compare-menu-calendar"
          onCloseWithSelection={(selection) =>
            navigate({
              search: getSearchToApplyCustomComparisonDates(selection)
            })
          }
          minDate={site.statsBegin}
          maxDate={formatISO(nowForSite(site))}
          defaultDates={
            query.compare_from && query.compare_to
              ? [formatISO(query.compare_from), formatISO(query.compare_to)]
              : undefined
          }
          onCloseWithNoSelection={() => setMenuVisible(false)}
        />
      )}
      <Transition
        {...popover.transition.props}
        className={classNames(
          'mt-2',
          popover.transition.classNames.fullwidth,
          'md:left-auto md:w-56'
        )}
      >
        <Menu.Items className={popover.panel.classNames.roundedSheet}>
          {[
            ComparisonMode.off,
            ComparisonMode.previous_period,
            ComparisonMode.year_over_year
          ].map((comparisonMode) => (
            <Menu.Item
              key={comparisonMode}
              disabled={query.comparison === comparisonMode}
            >
              <AppNavigationLink
                className={linkClassName}
                search={(search) => ({
                  ...search,
                  ...clearedComparisonSearch,
                  comparison: comparisonMode
                })}
              >
                {COMPARISON_MODES[comparisonMode]}
              </AppNavigationLink>
            </Menu.Item>
          ))}
          <Menu.Item>
            {({ close: closeDropdown }) => (
              <AppNavigationLink
                className={linkClassName}
                search={(s) => s}
                onClick={(e) => {
                  // custom handler is needed to prevent
                  // the calendar from immediately closing
                  // due to Menu.Button grabbing focus
                  setMenuVisible(true)
                  e.stopPropagation()
                  e.preventDefault()
                  closeDropdown()
                }}
              >
                {COMPARISON_MODES[ComparisonMode.custom]}
              </AppNavigationLink>
            )}
          </Menu.Item>
          {query.comparison !== ComparisonMode.custom && (
            <>
              <MenuSeparator />
              <Menu.Item disabled={query.match_day_of_week === true}>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => ({ ...s, match_day_of_week: true })}
                >
                  {
                    COMPARISON_MATCH_MODE_LABELS[
                      ComparisonMatchMode.MatchDayOfWeek
                    ]
                  }
                </AppNavigationLink>
              </Menu.Item>
              <Menu.Item disabled={query.match_day_of_week === false}>
                <AppNavigationLink
                  className={linkClassName}
                  search={(s) => ({ ...s, match_day_of_week: false })}
                >
                  {
                    COMPARISON_MATCH_MODE_LABELS[
                      ComparisonMatchMode.MatchExactDate
                    ]
                  }
                </AppNavigationLink>
              </Menu.Item>
            </>
          )}
        </Menu.Items>
      </Transition>
    </>
  )
}

export const ComparisonPeriodMenuButton = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const ref = useRef<HTMLButtonElement>(null)
  return (
    <>
      <BlurMenuButtonOnEscape targetRef={ref} />
      <Menu.Button className={datemenuButtonClassName} ref={ref}>
        {query.comparison === ComparisonMode.custom &&
        query.compare_from &&
        query.compare_to
          ? formatDateRange(site, query.compare_from, query.compare_to)
          : COMPARISON_MODES[query.comparison!]}
        <DateMenuChevron />
      </Menu.Button>
    </>
  )
}
