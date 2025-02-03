/** @format */

import React, { useCallback, useEffect, useRef, useState } from 'react'
import { clearedComparisonSearch } from '../../query'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { BlurMenuButtonOnEscape } from '../../keybinding'
import {
  AppNavigationLink,
  useAppNavigate
} from '../../navigation/use-app-navigate'
import {
  COMPARISON_MODES,
  ComparisonMode,
  isComparisonEnabled,
  COMPARISON_MATCH_MODE_LABELS,
  ComparisonMatchMode,
  getCurrentComparisonPeriodDisplayName,
  getSearchToApplyCustomComparisonDates
} from '../../query-time-periods'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  datemenuButtonClassName,
  DateMenuChevron,
  PopoverMenuProps,
  linkClassName,
  MenuSeparator
} from './shared-menu-items'
import { DateRangeCalendar } from './date-range-calendar'
import { formatISO, nowForSite } from '../../util/date'

export const ComparisonPeriodMenuItems = ({
  dropdownIsOpen,
  closeDropdown
}: PopoverMenuProps) => {
  const site = useSiteContext()
  const navigate = useAppNavigate()
  const { query } = useQueryContext()
  const [calendarIsOpen, setCalendarIsOpen] = useState(false)
  const closeCalendar = useCallback(() => setCalendarIsOpen(false), [])
  const openCalendar = useCallback(() => setCalendarIsOpen(true), [])

  useEffect(() => {
    if (!dropdownIsOpen) {
      closeCalendar()
    }
    return closeCalendar
  }, [dropdownIsOpen, closeCalendar])

  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (calendarIsOpen && panelRef.current?.focus) {
      panelRef.current.focus()
    }
  }, [calendarIsOpen])

  if (!isComparisonEnabled(query.comparison)) {
    return null
  }

  return (
    <Transition
      {...popover.transition.props}
      className={classNames(
        'mt-2',
        popover.transition.classNames.fullwidth,
        calendarIsOpen ? 'md:left-auto' : 'md:left-auto md:w-56'
      )}
    >
      <Popover.Panel
        ref={panelRef}
        className={
          calendarIsOpen
            ? '*:!top-auto *:!right-0 *:!absolute'
            : popover.panel.classNames.roundedSheet
        }
      >
        {calendarIsOpen && (
          <DateRangeCalendar
            id="calendar"
            onCloseWithSelection={(selection) => {
              navigate({
                search: getSearchToApplyCustomComparisonDates(selection)
              })
              closeDropdown()
            }}
            minDate={site.statsBegin}
            maxDate={formatISO(nowForSite(site))}
            defaultDates={
              query.compare_from && query.compare_to
                ? [formatISO(query.compare_from), formatISO(query.compare_to)]
                : undefined
            }
          />
        )}
        {!calendarIsOpen && (
          <>
            {[
              ComparisonMode.off,
              ComparisonMode.previous_period,
              ComparisonMode.year_over_year
            ].map((comparisonMode) => (
              <AppNavigationLink
                key={comparisonMode}
                data-selected={query.comparison === comparisonMode}
                className={linkClassName}
                search={(search) => ({
                  ...search,
                  ...clearedComparisonSearch,
                  comparison: comparisonMode
                })}
                onClick={closeDropdown}
              >
                {COMPARISON_MODES[comparisonMode]}
              </AppNavigationLink>
            ))}
            <AppNavigationLink
              data-selected={query.comparison === ComparisonMode.custom}
              className={linkClassName}
              search={(s) => s}
              onClick={() => {
                openCalendar()
              }}
            >
              {COMPARISON_MODES[ComparisonMode.custom]}
            </AppNavigationLink>
            {query.comparison !== ComparisonMode.custom && (
              <>
                <MenuSeparator />
                <AppNavigationLink
                  data-selected={query.match_day_of_week === true}
                  className={linkClassName}
                  search={(s) => ({ ...s, match_day_of_week: true })}
                  onClick={closeDropdown}
                >
                  {
                    COMPARISON_MATCH_MODE_LABELS[
                      ComparisonMatchMode.MatchDayOfWeek
                    ]
                  }
                </AppNavigationLink>
                <AppNavigationLink
                  data-selected={query.match_day_of_week === false}
                  className={linkClassName}
                  search={(s) => ({ ...s, match_day_of_week: false })}
                  onClick={closeDropdown}
                >
                  {
                    COMPARISON_MATCH_MODE_LABELS[
                      ComparisonMatchMode.MatchExactDate
                    ]
                  }
                </AppNavigationLink>
              </>
            )}
          </>
        )}
      </Popover.Panel>
    </Transition>
  )
}

export const ComparisonPeriodMenuButton = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button className={datemenuButtonClassName} ref={buttonRef}>
        <span className={popover.toggleButton.classNames.truncatedText}>
          {getCurrentComparisonPeriodDisplayName({ site, query })}
        </span>
        <DateMenuChevron />
      </Popover.Button>
    </>
  )
}
