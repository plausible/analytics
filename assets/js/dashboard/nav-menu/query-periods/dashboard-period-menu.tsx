import React, { useMemo, useRef } from 'react'
import classNames from 'classnames'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
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
  getDatePeriodGroups,
  LinkItem,
  DashboardPeriod,
  getCurrentPeriodDisplayName,
  getSearchToApplyCustomDates,
  isComparisonForbidden
} from '../../dashboard-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { Popover, Transition } from '@headlessui/react'
import { popover, BlurMenuButtonOnEscape } from '../../components/popover'
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

function DashboardPeriodMenuKeybinds({
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
      {groups.flatMap((group) =>
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

export const DashboardPeriodMenu = ({
  closeDropdown,
  calendarButtonRef
}: PopoverMenuProps) => {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
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
        <span
          data-testid="current-query-period"
          className={popover.toggleButton.classNames.truncatedText}
        >
          {getCurrentPeriodDisplayName({ dashboardState, site })}
        </span>
        <DateMenuChevron />
      </Popover.Button>
      <DashboardPeriodMenuInner
        toggleCalendar={toggleCalendar}
        closeDropdown={closeDropdown}
      />
    </>
  )
}

const DashboardPeriodMenuInner = ({
  closeDropdown,
  toggleCalendar
}: {
  closeDropdown: () => void
  toggleCalendar: () => void
}) => {
  const site = useSiteContext()
  const { dashboardState, expandedSegment } = useDashboardStateContext()

  const groups = useMemo(() => {
    const compareLink = getCompareLinkItem({
      site,
      dashboardState,
      onEvent: closeDropdown
    })
    return getDatePeriodGroups({
      site,
      onEvent: closeDropdown,
      extraItemsInLastGroup: [
        [
          ['Custom Range', 'C'],
          {
            search: (s) => s,
            isActive: ({ dashboardState }) =>
              dashboardState.period === DashboardPeriod.custom,
            onEvent: toggleCalendar
          }
        ]
      ],
      extraGroups: isComparisonForbidden({
        period: dashboardState.period,
        segmentIsExpanded: !!expandedSegment
      })
        ? []
        : [[compareLink]]
    })
  }, [site, dashboardState, closeDropdown, toggleCalendar, expandedSegment])

  return (
    <>
      <DashboardPeriodMenuKeybinds
        closeDropdown={closeDropdown}
        groups={groups}
      />
      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(
          popover.transition.classNames.fullwidth,
          'mt-2 md:w-56 md:left-auto md:origin-top-right'
        )}
      >
        <Popover.Panel
          className={popover.panel.classNames.roundedSheet}
          data-testid="datemenu"
        >
          {groups.map((group, index) => (
            <React.Fragment key={index}>
              {group.map(
                ([
                  [label, keyboardKey],
                  { search, isActive, onEvent, hidden }
                ]) => {
                  if (!hidden) {
                    return (
                      <AppNavigationLink
                        key={label}
                        data-selected={isActive({ site, dashboardState })}
                        className={linkClassName}
                        search={search}
                        onClick={onEvent && ((e) => onEvent(e))}
                      >
                        {label}
                        {!!keyboardKey && (
                          <KeybindHint>{keyboardKey}</KeybindHint>
                        )}
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
  const { dashboardState } = useDashboardStateContext()
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
            dashboardState.from && dashboardState.to
              ? [formatISO(dashboardState.from), formatISO(dashboardState.to)]
              : undefined
          }
        />
      </CalendarPanel>
    </>
  )
}
