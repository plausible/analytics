import React, { useMemo, useRef } from 'react'
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
  getCompareLinkItem,
  last6MonthsLinkItem,
  getDatePeriodGroups,
  LinkItem,
  QueryPeriod,
  getCurrentPeriodDisplayName,
  getSearchToApplyCustomDates,
  isComparisonForbidden
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
  CalendarPanel,
  hiddenCalendarButtonClassName
} from './shared-menu-items'
import { DateRangeCalendar } from './date-range-calendar'
import { formatISO, nowForSite } from '../../util/date'
import { MenuSeparator } from '../nav-menu-components'

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
  calendarButtonRef
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
      <Popover.Button ref={buttonRef} className={datemenuButtonClassName}>
        <span className={popover.toggleButton.classNames.truncatedText}>
          {getCurrentPeriodDisplayName({ query, site })}
        </span>
        <DateMenuChevron />
      </Popover.Button>
      <QueryPeriodMenuInner
        toggleCalendar={toggleCalendar}
        closeDropdown={closeDropdown}
      />
    </>
  )
}

const QueryPeriodMenuInner = ({
  closeDropdown,
  toggleCalendar
}: {
  closeDropdown: () => void
  toggleCalendar: () => void
}) => {
  const site = useSiteContext()
  const { query, expandedSegment } = useQueryContext()

  const groups = useMemo(() => {
    const compareLink = getCompareLinkItem({ site, query })
    return getDatePeriodGroups({
      site,
      onEvent: closeDropdown,
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
      extraGroups: isComparisonForbidden({
        period: query.period,
        segmentIsExpanded: !!expandedSegment
      })
        ? []
        : [[compareLink]]
    })
  }, [site, query, closeDropdown, toggleCalendar, expandedSegment])

  return (
    <>
      <QueryPeriodMenuKeybinds closeDropdown={closeDropdown} groups={groups} />
      <Transition
        {...popover.transition.props}
        className={classNames(
          'mt-2',
          popover.transition.classNames.fullwidth,
          'md:left-auto md:w-56'
        )}
      >
        <Popover.Panel
          className={popover.panel.classNames.roundedSheet}
          data-testid="datemenu"
        >
          {groups.map((group, index) => (
            <React.Fragment key={index}>
              {group.map(
                ([[label, keyboardKey], { search, isActive, onEvent, hidden }]) => {
                  if (!hidden) {
                    return (
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
                  }
                }
              )}
              {index < groups.length - 1 && <MenuSeparator />}
            </React.Fragment>
          ))}
        </Popover.Panel>
      </Transition>
    </>
  )
}

export const MainCalendar = ({
  closeDropdown,
  calendarButtonRef
}: PopoverMenuProps) => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()

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
              search: getSearchToApplyCustomDates(selection)
            })
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
      </CalendarPanel>
    </>
  )
}
