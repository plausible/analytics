/** @format */

import React, { useEffect, useRef } from 'react'
import { formatDateRange } from '../../util/date'
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
  ComparisonMatchMode
} from '../../query-time-periods'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  datemenuButtonClassName,
  DateMenuChevron,
  linkClassName,
  MenuSeparator
} from './shared-menu-items'

export const ComparisonPeriodMenuItems = ({
  closeDropdown,
  toggleCalendar
}: {
  closeDropdown: () => void
  toggleCalendar: () => void
}) => {
  const { query } = useQueryContext()

  useEffect(() => {
    closeDropdown()
  }, [closeDropdown, query])

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
              toggleCalendar()
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
  const buttonRef = useRef<HTMLButtonElement>(null)
  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button className={datemenuButtonClassName} ref={buttonRef}>
        <CurrentComparison />
        <DateMenuChevron />
      </Popover.Button>
    </>
  )
}

const CurrentComparison = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()

  if (!isComparisonEnabled(query.comparison)) {
    return null
  }

  return query.comparison === ComparisonMode.custom &&
    query.compare_from &&
    query.compare_to
    ? formatDateRange(site, query.compare_from, query.compare_to)
    : COMPARISON_MODES[query.comparison]
}
