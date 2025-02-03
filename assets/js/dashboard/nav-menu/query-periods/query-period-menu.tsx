/** @format */

import React, { useRef, useMemo, useEffect, useCallback, useState } from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import {
  BlurMenuButtonOnEscape,
  isModifierPressed,
  isTyping,
  Keybind,
  KeybindHint
} from '../../keybinding'
import {
  AppNavigationLink,
  useAppNavigate
} from '../../navigation/use-app-navigate'
import {
  COMPARISON_DISABLED_PERIODS,
  getCompareLinkItem,
  last6MonthsLinkItem,
  getDatePeriodGroups,
  LinkItem,
  QueryPeriod,
  getCurrentPeriodDisplayName,
  getSearchToApplyCustomDates
} from '../../query-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
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

function QueryPeriodMenuItems({
  groups,
  calendarIsOpen,
  closeDropdown
}: { groups: LinkItem[][] } & Pick<PopoverMenuProps, 'closeDropdown'> & {
    calendarIsOpen: boolean
  }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (calendarIsOpen && panelRef.current?.focus) {
      panelRef.current.focus()
    }
  }, [calendarIsOpen])

  return (
    <Transition
      {...popover.transition.props}
      className={classNames(
        'mt-2',
        popover.transition.classNames.fullwidth,
        calendarIsOpen ? 'md-left-auto' : 'md:left-auto md:w-56'
      )}
    >
      <Popover.Panel
        ref={panelRef}
        className={
          calendarIsOpen
            ? '*:!top-auto *:!right-0 *:!absolute'
            : popover.panel.classNames.roundedSheet
        }
        data-testid="datemenu"
      >
        {calendarIsOpen && (
          <DateRangeCalendar
            id="calendar"
            onCloseWithSelection={(selection) => {
              navigate({
                search: getSearchToApplyCustomDates(selection)
              })
              console.log('here')
              closeDropdown()
            }}
            minDate={site.statsBegin}
            maxDate={formatISO(nowForSite(site))}
            defaultDates={
              query.from && query.to
                ? [formatISO(query.from), formatISO(query.to)]
                : undefined
            }
          />
        )}
        {!calendarIsOpen &&
          groups.map((group, index) => (
            <React.Fragment key={index}>
              {group.map(
                ([[label, keyboardKey], { search, isActive, onEvent }]) => (
                  <AppNavigationLink
                    key={label}
                    data-selected={isActive({ site, query })}
                    className={linkClassName}
                    search={search}
                    onClick={onEvent && ((e) => onEvent(e))}
                  >
                    {label}
                    {!!keyboardKey && <KeybindHint>{keyboardKey}</KeybindHint>}
                  </AppNavigationLink>
                )
              )}
              {index < groups.length - 1 && <MenuSeparator />}
            </React.Fragment>
          ))}
      </Popover.Panel>
    </Transition>
  )
}

function QueryPeriodMenuKeybinds({
  closeDropdown,
  groups
}: {
  groups: LinkItem[][]
  closeDropdown: () => void
}) {
  const dashboardRouteMatch = useMatch(rootRoute.path)
  const navigate = useAppNavigate()

  if (!dashboardRouteMatch) {
    return null
  }
  return (
    <>
      {groups.concat([[last6MonthsLinkItem]]).flatMap((group) =>
        group
          .filter(([[_name, keyboardKey]]) => !!keyboardKey)
          .map(([[_name, keyboardKey], { search, onEvent }]) => (
            <Keybind
              key={keyboardKey}
              keyboardKey={keyboardKey}
              type="keydown"
              handler={(e) => {
                if (typeof search === 'function') {
                  navigate({ search })
                }
                if (typeof onEvent === 'function') {
                  onEvent(e)
                } else {
                  closeDropdown()
                }
              }}
              shouldIgnoreWhen={[isModifierPressed, isTyping]}
              targetRef="document"
            />
          ))
      )}
    </>
  )
}

export const QueryPeriodMenu = ({
  closeDropdown,
  dropdownIsOpen
}: PopoverMenuProps) => {
  const buttonRef = useRef<HTMLButtonElement>(null)
  const site = useSiteContext()
  const { query } = useQueryContext()

  const [calendarIsOpen, setCalendarIsOpen] = useState(false)
  const closeCalendar = useCallback(() => setCalendarIsOpen(false), [])
  const openCalendar = useCallback(() => setCalendarIsOpen(true), [])

  useEffect(() => {
    if (!dropdownIsOpen) {
      closeCalendar()
    }
  }, [dropdownIsOpen, closeCalendar])

  const toggleCalendar = useCallback(() => {
    if (calendarIsOpen) {
      closeDropdown()
    } else {
      openCalendar()
      if (!dropdownIsOpen) {
        console.log('hi')
        buttonRef.current?.click()
      }
    }
  }, [dropdownIsOpen, calendarIsOpen, openCalendar, closeDropdown])

  const groups = useMemo(() => {
    const compareLink = getCompareLinkItem({ site, query })
    return getDatePeriodGroups({
      site,
      onEvent: () => closeDropdown(),
      extraItemsInLastGroup: [
        [
          ['Custom Range', 'C'],
          {
            search: (s) => s,
            isActive: ({ query }) => query.period === QueryPeriod.custom,
            onEvent: toggleCalendar
          }
        ]
      ],
      extraGroups: COMPARISON_DISABLED_PERIODS.includes(query.period)
        ? []
        : [[compareLink]]
    })
  }, [site, query, toggleCalendar, closeDropdown])

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button ref={buttonRef} className={datemenuButtonClassName}>
        <span className={popover.toggleButton.classNames.truncatedText}>
          {getCurrentPeriodDisplayName({ query, site })}
        </span>
        <DateMenuChevron />
      </Popover.Button>
      <QueryPeriodMenuKeybinds closeDropdown={closeDropdown} groups={groups} />
      <QueryPeriodMenuItems
        groups={groups}
        calendarIsOpen={calendarIsOpen}
        closeDropdown={closeDropdown}
      />
    </>
  )
}
