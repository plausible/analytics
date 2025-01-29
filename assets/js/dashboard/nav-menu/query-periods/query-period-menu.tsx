/** @format */

import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react'
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

export function QueryPeriodMenu({ className }: { className?: string }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()
  const [menuVisible, setMenuVisible] = useState<boolean>(false)

  const periodMenuButtonRef = useRef<HTMLButtonElement>(null)

  const dashboardRouteMatch = useMatch(rootRoute.path)

  const closeMenu = useCallback(() => {
    setMenuVisible(false)
  }, [])

  const buttonGroups = useMemo(() => {
    const groups = getDatePeriodGroups(site)
    return groups
  }, [site])

  const compareLink: LinkItem = useMemo(
    () => getCompareLinkItem({ site, query }),
    [site, query]
  )

  useEffect(() => {
    closeMenu()
  }, [closeMenu, query])

  return (
    <Menu as="div" className={className}>
      {({ close: closeDropdown }) => {
        const groups = buttonGroups
          .slice(0, buttonGroups.length - 1)
          .concat([
            // add Custom Range link to the last group
            buttonGroups[buttonGroups.length - 1].concat([
              [
                ['Custom Range', 'C'],
                {
                  search: (s) => s,
                  isActive: () => false,
                  onClick: (e) => {
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
            ])
          ])
          // maybe add Compare link as another group to the very end
          .concat(
            COMPARISON_DISABLED_PERIODS.includes(query.period)
              ? []
              : [[compareLink]]
          )

        return (
          <>
            {!!dashboardRouteMatch && (
              <>
                {groups.concat([[last6MonthsLinkItem]]).flatMap((group) =>
                  group
                    .filter(([[_name, keyboardKey]]) => !!keyboardKey)
                    .map(([[_name, keyboardKey], { search, onClick }]) => (
                      <Keybind
                        key={keyboardKey}
                        keyboardKey={keyboardKey}
                        type="keydown"
                        handler={(e) => {
                          if (typeof search === 'function') {
                            navigate({ search })
                          }
                          if (typeof onClick === 'function') {
                            onClick(e)
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
            )}
            <BlurMenuButtonOnEscape targetRef={periodMenuButtonRef} />
            <Menu.Button
              ref={periodMenuButtonRef}
              className={datemenuButtonClassName}
            >
              <DisplaySelectedPeriod />
              <DateMenuChevron />
            </Menu.Button>
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
                      ([
                        [label, keyboardKey],
                        { search, isActive, onClick }
                      ]) => (
                        <Menu.Item
                          disabled={isActive({ site, query })}
                          key={label}
                        >
                          <AppNavigationLink
                            className={linkClassName}
                            search={search}
                            onClick={
                              onClick && ((e) => onClick(e as unknown as Event))
                            }
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
      }}
    </Menu>
  )
}
