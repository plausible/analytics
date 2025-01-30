/** @format */

import React, { useRef, useMemo } from 'react'
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
  DisplaySelectedPeriod,
  getCompareLinkItem,
  last6MonthsLinkItem,
  getDatePeriodGroups,
  LinkItem,
  QueryPeriod
} from '../../query-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'
import { Popover, Transition } from '@headlessui/react'
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
        <Popover.Panel
          className={popover.panel.classNames.roundedSheet}
          data-testid="datemenu"
        >
          {groups.map((group, index) => (
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

export const QueryPeriodMenuButton = () => {
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button ref={buttonRef} className={datemenuButtonClassName}>
        <DisplaySelectedPeriod />
        <DateMenuChevron />
      </Popover.Button>
    </>
  )
}

export const QueryPeriodMenu = ({
  closeDropdown,
  toggleCalendar
}: {
  closeDropdown: () => void
  toggleCalendar: () => void
}) => {
  const site = useSiteContext()
  const { query } = useQueryContext()

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
            onEvent: () => {
              toggleCalendar()
              closeDropdown()
            }
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
      <QueryPeriodMenuKeybinds closeDropdown={closeDropdown} groups={groups} />
      <QueryPeriodMenuItems groups={groups} />
    </>
  )
}
