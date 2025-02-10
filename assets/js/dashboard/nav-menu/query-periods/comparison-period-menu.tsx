/** @format */

import React, { useRef } from 'react'
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
  MenuSeparator,
  CalendarPanel,
  hiddenCalendarButtonClassName
} from './shared-menu-items'
import { DateRangeCalendar } from './date-range-calendar'
import { formatISO, nowForSite } from '../../util/date'

export const ComparisonPeriodMenuItems = ({
  closeDropdown,
  toggleCalendar
}: {
  closeDropdown: () => void
  toggleCalendar: () => void
}) => {
  const { query } = useQueryContext()

  if (!isComparisonEnabled(query.comparison)) {
    return null
  }

  return (
    <Transition
      {...popover.transition.props}
      className={classNames(
        'mt-2',
        popover.transition.classNames.fullwidth,
        'md:left-auto md:w-56'
      )}
    >
      <Popover.Panel className={popover.panel.classNames.roundedSheet}>
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
          onClick={toggleCalendar}
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
              {COMPARISON_MATCH_MODE_LABELS[ComparisonMatchMode.MatchDayOfWeek]}
            </AppNavigationLink>
            <AppNavigationLink
              data-selected={query.match_day_of_week === false}
              className={linkClassName}
              search={(s) => ({ ...s, match_day_of_week: false })}
              onClick={closeDropdown}
            >
              {COMPARISON_MATCH_MODE_LABELS[ComparisonMatchMode.MatchExactDate]}
            </AppNavigationLink>
          </>
        )}
      </Popover.Panel>
    </Transition>
  )
}

export const ComparisonPeriodMenu = ({
  calendarButtonRef,
  closeDropdown
}: PopoverMenuProps) => {
  const site = useSiteContext()
  const { query } = useQueryContext()

  const buttonRef = useRef<HTMLButtonElement>(null)
  const toggleCalendar = () => {
    if (typeof calendarButtonRef.current?.click === 'function') {
      calendarButtonRef.current.click()
    }
  }

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button className={datemenuButtonClassName} ref={buttonRef}>
        <span className={popover.toggleButton.classNames.truncatedText}>
          {getCurrentComparisonPeriodDisplayName({ site, query })}
        </span>
        <DateMenuChevron />
      </Popover.Button>
      <ComparisonPeriodMenuItems
        closeDropdown={closeDropdown}
        toggleCalendar={toggleCalendar}
      />
    </>
  )
}

export const ComparisonCalendarMenu = ({
  closeDropdown,
  calendarButtonRef
}: PopoverMenuProps) => {
  const site = useSiteContext()
  const navigate = useAppNavigate()
  const { query } = useQueryContext()

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={calendarButtonRef} />
      <Popover.Button
        className={hiddenCalendarButtonClassName}
        tabIndex={-1}
        ref={calendarButtonRef}
      />
      <CalendarPanel className="mt-2">
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
      </CalendarPanel>
    </>
  )
}
