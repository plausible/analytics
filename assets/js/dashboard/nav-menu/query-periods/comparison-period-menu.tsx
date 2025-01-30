/** @format */

import React, { useRef } from 'react'
import { clearedComparisonSearch } from '../../query'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { BlurMenuButtonOnEscape } from '../../keybinding'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import {
  COMPARISON_MODES,
  ComparisonMode,
  isComparisonEnabled,
  COMPARISON_MATCH_MODE_LABELS,
  ComparisonMatchMode,
  getCurrentComparisonPeriodDisplayName
} from '../../query-time-periods'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  datemenuButtonClassName,
  DateMenuChevron,
  DropdownItemsProps,
  linkClassName,
  MenuSeparator,
  useCloseCalendarOnDropdownOpen
} from './shared-menu-items'

export const ComparisonPeriodMenuItems = ({
  dropdownIsOpen,
  closeDropdown,
  openCalendar,
  closeCalendar,
  calendarIsOpen
}: DropdownItemsProps) => {
  const { query } = useQueryContext()

  useCloseCalendarOnDropdownOpen({
    dropdownIsOpen,
    calendarIsOpen,
    closeCalendar
  })

  if (!isComparisonEnabled(query.comparison)) {
    return null
  }

  return (
    <>
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
            onClick={() => {
              // custom handler is needed to prevent
              // the calendar from immediately closing
              // due to Menu.Button grabbing focus
              openCalendar()
              closeDropdown()
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
        </Popover.Panel>
      </Transition>
    </>
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
