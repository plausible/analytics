/** @format */

import React, {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo,
  memo
} from 'react'
import { formatISO, nowForSite } from '../../util/date'
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
import { DateRangeCalendar } from './date-range-calendar'
import {
  COMPARISON_DISABLED_PERIODS,
  DisplaySelectedPeriod,
  getCompareLinkItem,
  getSearchToApplyCustomDates,
  last6MonthsLinkItem,
  getDatePeriodGroups,
  LinkItem
} from '../../query-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { Menu, Transition } from '@headlessui/react'
import { popover } from '../../components/popover'
import {
  datemenuButtonClassName,
  DateMenuChevron,
  linkClassName,
  MenuSeparator
} from './shared-menu-items'

function QueryPeriodMenuItems({ groups }: { groups: LinkItem[][] }) {
  const site = useSiteContext()
  const { query } = useQueryContext()

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
        <Menu.Items className={popover.panel.classNames.roundedSheet}>
          {groups.map((group, index) => (
            <React.Fragment key={index}>
              {group.map(
                ([[label, keyboardKey], { search, isActive, onEvent }]) => (
                  <Menu.Item disabled={isActive({ site, query })} key={label}>
                    <AppNavigationLink
                      className={linkClassName}
                      search={search}
                      onClick={onEvent && ((e) => onEvent(e))}
                    >
                      {label}
                      {!!keyboardKey && (
                        <KeybindHint>{keyboardKey}</KeybindHint>
                      )}
                    </AppNavigationLink>
                  </Menu.Item>
                )
              )}
              {index < groups.length - 1 && <MenuSeparator />}
            </React.Fragment>
          ))}
        </Menu.Items>
      </Transition>
    </>
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

const QueryPeriodMenuButton = () => {
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Menu.Button ref={buttonRef} className={datemenuButtonClassName}>
        <DisplaySelectedPeriod />
        <DateMenuChevron />
      </Menu.Button>
    </>
  )
}

/**
 * This menu is memoised to prevent too frequent rerenders when
 * headless UI Menu render props change.
 */
export const MemoisedQueryPeriodMenu = memo(
  ({ closeDropdown }: { closeDropdown: () => void }) => {
    const site = useSiteContext()
    const { query } = useQueryContext()
    const [menuVisible, setMenuVisible] = useState<boolean>(false)
    const navigate = useAppNavigate()

    const closeMenu = useCallback(() => {
      setMenuVisible(false)
    }, [])

    useEffect(() => {
      closeMenu()
    }, [closeMenu, query])

    const groups = useMemo(() => {
      const compareLink = getCompareLinkItem({ site, query })
      return getDatePeriodGroups({
        site,
        extraItemsInLastGroup: [
          [
            ['Custom Range', 'C'],
            {
              search: (s) => s,
              isActive: () => false,
              onEvent: (e) => {
                // custom handler is needed to prevent
                // the calendar from immediately closing
                // due to Menu.Button grabbing focus
                setMenuVisible(true)
                e.preventDefault()
                e.stopPropagation()
                closeDropdown()
              }
            }
          ]
        ],
        extraGroups: COMPARISON_DISABLED_PERIODS.includes(query.period)
          ? []
          : [[compareLink]]
      })
    }, [site, query, setMenuVisible, closeDropdown])

    return (
      <>
        <QueryPeriodMenuButton />
        <QueryPeriodMenuKeybinds
          closeDropdown={closeDropdown}
          groups={groups}
        />
        {menuVisible && (
          <DateRangeCalendar
            id="calendar"
            onCloseWithSelection={(selection) =>
              navigate({ search: getSearchToApplyCustomDates(selection) })
            }
            minDate={site.statsBegin}
            maxDate={formatISO(nowForSite(site))}
            defaultDates={
              query.to && query.from
                ? [formatISO(query.from), formatISO(query.to)]
                : undefined
            }
            onCloseWithNoSelection={() => setMenuVisible(false)}
          />
        )}
        <QueryPeriodMenuItems groups={groups} />
      </>
    )
  }
)
