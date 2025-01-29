/* @format */
import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { formatDateRange, formatISO, nowForSite } from './util/date'
import {
  shiftQueryPeriod,
  getDateForShiftedPeriod,
  clearedComparisonSearch
} from './query'
import classNames from 'classnames'
import { useQueryContext } from './query-context'
import { useSiteContext } from './site-context'
import {
  BlurMenuButtonOnEscape,
  isModifierPressed,
  isTyping,
  Keybind,
  KeybindHint,
  NavigateKeybind
} from './keybinding'
import {
  AppNavigationLink,
  useAppNavigate
} from './navigation/use-app-navigate'
import { DateRangeCalendar } from './date-range-calendar'
import {
  COMPARISON_DISABLED_PERIODS,
  COMPARISON_MODES,
  ComparisonMode,
  DisplaySelectedPeriod,
  getCompareLinkItem,
  isComparisonEnabled,
  getSearchToApplyCustomComparisonDates,
  getSearchToApplyCustomDates,
  QueryPeriod,
  last6MonthsLinkItem,
  getDatePeriodGroups,
  LinkItem,
  COMPARISON_MATCH_MODE_LABELS,
  ComparisonMatchMode
} from './query-time-periods'
import { useOnClickOutside } from './util/use-on-click-outside'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  ToggleDropdownButton
} from './components/dropdown'
import { useMatch } from 'react-router-dom'
import { rootRoute } from './router'
import { Menu, Transition } from '@headlessui/react'
import { popover } from './components/popover'

const ArrowKeybind = ({
  keyboardKey
}: {
  keyboardKey: 'ArrowLeft' | 'ArrowRight'
}) => {
  const site = useSiteContext()
  const { query } = useQueryContext()

  const search = useMemo(
    () =>
      shiftQueryPeriod({
        query,
        site,
        direction: ({ ArrowLeft: -1, ArrowRight: 1 } as const)[keyboardKey],
        keybindHint: keyboardKey
      }),
    [site, query, keyboardKey]
  )

  return (
    <NavigateKeybind
      type="keydown"
      keyboardKey={keyboardKey}
      navigateProps={{ search }}
    />
  )
}

function ArrowIcon({ direction }: { direction: 'left' | 'right' }) {
  return (
    <svg
      className="feather h-4 w-4"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {direction === 'left' && <polyline points="15 18 9 12 15 6"></polyline>}
      {direction === 'right' && <polyline points="9 18 15 12 9 6"></polyline>}
    </svg>
  )
}

function MovePeriodArrows() {
  const periodsWithArrows = [
    QueryPeriod.year,
    QueryPeriod.month,
    QueryPeriod.day
  ]
  const { query } = useQueryContext()
  const site = useSiteContext()
  if (!periodsWithArrows.includes(query.period)) {
    return null
  }

  const canGoBack =
    getDateForShiftedPeriod({ site, query, direction: -1 }) !== null
  const canGoForward =
    getDateForShiftedPeriod({ site, query, direction: 1 }) !== null

  const isComparing = isComparisonEnabled(query.comparison)

  const sharedClass = 'flex items-center px-1 sm:px-2 dark:text-gray-100'
  const enabledClass = 'hover:bg-gray-100 dark:hover:bg-gray-900'
  const disabledClass = 'bg-gray-300 dark:bg-gray-950 cursor-not-allowed'

  const containerClass = classNames(
    'rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer dark:bg-gray-800',
    {
      'hidden md:flex': isComparing,
      flex: !isComparing
    }
  )

  return (
    <div className={containerClass}>
      <AppNavigationLink
        className={classNames(
          sharedClass,
          'rounded-l border-gray-300 dark:border-gray-500',
          { [enabledClass]: canGoBack, [disabledClass]: !canGoBack }
        )}
        search={
          canGoBack
            ? shiftQueryPeriod({
                site,
                query,
                direction: -1,
                keybindHint: null
              })
            : (search) => search
        }
      >
        <ArrowIcon direction="left" />
      </AppNavigationLink>
      <AppNavigationLink
        className={classNames(sharedClass, {
          [enabledClass]: canGoForward,
          [disabledClass]: !canGoForward
        })}
        search={
          canGoForward
            ? shiftQueryPeriod({
                site,
                query,
                direction: 1,
                keybindHint: null
              })
            : (search) => search
        }
      >
        <ArrowIcon direction="right" />
      </AppNavigationLink>
    </div>
  )
}

function QueryPeriodsMenu({
  groups,
  closeMenu
}: {
  groups: LinkItem[][]
  closeMenu: () => void
}) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  return (
    <DropdownMenuWrapper
      id="datemenu"
      data-testid="datemenu"
      innerContainerClassName="date-options"
      className="md:left-auto md:w-56"
    >
      {groups.map((group, index) => (
        <DropdownLinkGroup key={index} className="date-options-group">
          {group.map(
            ([[label, keyboardKey], { search, isActive, onClick }]) => (
              <DropdownNavigationLink
                key={label}
                active={isActive({ site, query })}
                search={search}
                onClick={onClick || closeMenu}
              >
                {label}
                {!!keyboardKey && <KeybindHint>{keyboardKey}</KeybindHint>}
              </DropdownNavigationLink>
            )
          )}
        </DropdownLinkGroup>
      ))}
    </DropdownMenuWrapper>
  )
}

const linkstyle = classNames(
  'flex items-center justify-between',
  `px-4 py-2 text-sm leading-tight`,
  `data-[headlessui-state=active]:bg-gray-100 data-[headlessui-state=active]:text-gray-900 dark:data-[headlessui-state=active]:bg-gray-900 dark:data-[headlessui-state=active]:text-gray-100`,
  `data-[headlessui-state=disabled]:font-bold data-[headlessui-state=disabled]:cursor-default`
)

export default function QueryPeriodPicker({
  className
}: {
  className?: string
}) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()
  const [menuVisible, setMenuVisible] = useState<
    | 'datemenu'
    | 'datemenu-calendar'
    | 'compare-menu'
    | 'compare-menu-calendar'
    | null
  >(null)
  const dropdownRef = useRef<HTMLDivElement>(null)
  const compareDropdownRef = useRef<HTMLButtonElement>(null)

  const dashboardRouteMatch = useMatch(rootRoute.path)

  const closeMenu = useCallback(() => {
    setMenuVisible(null)
  }, [])

  const toggleDateMenu = useCallback(() => {
    setMenuVisible((prevState) =>
      prevState === 'datemenu' ? null : 'datemenu'
    )
  }, [])

  const toggleDateMenuCalendar = useCallback(() => {
    setMenuVisible((prevState) =>
      prevState === 'datemenu-calendar' ? null : 'datemenu-calendar'
    )
  }, [])

  const customRangeLink: LinkItem = useMemo(
    () => [
      ['Custom Range', 'C'],
      {
        search: (s) => s,
        isActive: ({ query }) => query.period === QueryPeriod.custom,
        onClick: toggleDateMenuCalendar
      }
    ],
    [toggleDateMenuCalendar]
  )
  const compareLink: LinkItem = useMemo(
    () => getCompareLinkItem({ site, query }),
    [site, query]
  )

  const datePeriodGroups = useMemo(() => {
    const groups = getDatePeriodGroups(site)
    // add Custom Range link to the last group
    groups[groups.length - 1].push(customRangeLink)

    if (COMPARISON_DISABLED_PERIODS.includes(query.period)) {
      return groups
    }
    // maybe add Compare link as another group to the very end
    return groups.concat([[compareLink]])
  }, [site, query, customRangeLink, compareLink])

  useOnClickOutside({
    ref: dropdownRef,
    active: menuVisible === 'datemenu',
    handler: closeMenu
  })

  useEffect(() => {
    closeMenu()
  }, [closeMenu, query])

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows />
      <ToggleDropdownButton
        withDropdownIndicator
        className="min-w-36 md:relative lg:w-48"
        currentOption={<DisplaySelectedPeriod />}
        ref={dropdownRef}
        onClick={toggleDateMenu}
        dropdownContainerProps={{
          ['aria-controls']: 'datemenu',
          ['aria-expanded']: menuVisible === 'datemenu'
        }}
      >
        {menuVisible === 'datemenu' && (
          <QueryPeriodsMenu groups={datePeriodGroups} closeMenu={closeMenu} />
        )}

        {menuVisible === 'datemenu-calendar' && (
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
            onCloseWithNoSelection={() => setMenuVisible(null)}
          />
        )}
      </ToggleDropdownButton>
      {isComparisonEnabled(query.comparison) && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Menu as="div" className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <>
                <BlurMenuButtonOnEscape targetRef={compareDropdownRef} />
                <Menu.Button
                  className={classNames(
                    'flex items-center rounded text-sm leading-tight px-2 py-2 h-9',
                    'w-full justify-between bg-white dark:bg-gray-800 shadow text-gray-800 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900'
                  )}
                  ref={compareDropdownRef}
                >
                  {query.comparison === ComparisonMode.custom &&
                  query.compare_from &&
                  query.compare_to
                    ? formatDateRange(
                        site,
                        query.compare_from,
                        query.compare_to
                      )
                    : COMPARISON_MODES[query.comparison!]}
                </Menu.Button>
                {menuVisible === 'compare-menu-calendar' && (
                  <DateRangeCalendar
                    id="compare-menu-calendar"
                    onCloseWithSelection={(selection) =>
                      navigate({
                        search: getSearchToApplyCustomComparisonDates(selection)
                      })
                    }
                    minDate={site.statsBegin}
                    maxDate={formatISO(nowForSite(site))}
                    defaultDates={
                      query.compare_from && query.compare_to
                        ? [
                            formatISO(query.compare_from),
                            formatISO(query.compare_to)
                          ]
                        : undefined
                    }
                    onCloseWithNoSelection={() => setMenuVisible(null)}
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
                    {[
                      ComparisonMode.off,
                      ComparisonMode.previous_period,
                      ComparisonMode.year_over_year
                    ].map((comparisonMode) => (
                      <Menu.Item
                        key={comparisonMode}
                        disabled={query.comparison === comparisonMode}
                      >
                        <AppNavigationLink
                          className={linkstyle}
                          search={(search) => ({
                            ...search,
                            ...clearedComparisonSearch,
                            comparison: comparisonMode
                          })}
                        >
                          {COMPARISON_MODES[comparisonMode]}
                        </AppNavigationLink>
                      </Menu.Item>
                    ))}
                    <Menu.Item>
                      <AppNavigationLink
                        className={linkstyle}
                        search={(s) => s}
                        onClick={(e) => {
                          // custom handler is needed to prevent
                          // the calendar from immediately closing
                          // due to Menu.Button grabbing focus
                          setMenuVisible('compare-menu-calendar')
                          e.stopPropagation()
                          e.preventDefault()
                          close()
                        }}
                      >
                        {COMPARISON_MODES[ComparisonMode.custom]}
                      </AppNavigationLink>
                    </Menu.Item>
                    {query.comparison !== ComparisonMode.custom && (
                      <>
                        <div className="my-1 border-gray-200 dark:border-gray-500 border-b" />
                        <Menu.Item disabled={query.match_day_of_week === true}>
                          <AppNavigationLink
                            className={linkstyle}
                            search={(s) => ({ ...s, match_day_of_week: true })}
                          >
                            {
                              COMPARISON_MATCH_MODE_LABELS[
                                ComparisonMatchMode.MatchDayOfWeek
                              ]
                            }
                          </AppNavigationLink>
                        </Menu.Item>
                        <Menu.Item disabled={query.match_day_of_week === false}>
                          <AppNavigationLink
                            className={linkstyle}
                            search={(s) => ({ ...s, match_day_of_week: false })}
                          >
                            {
                              COMPARISON_MATCH_MODE_LABELS[
                                ComparisonMatchMode.MatchExactDate
                              ]
                            }
                          </AppNavigationLink>
                        </Menu.Item>
                      </>
                    )}
                  </Menu.Items>
                </Transition>
              </>
            )}
          </Menu>
        </>
      )}
      {!!dashboardRouteMatch && (
        <>
          <ArrowKeybind keyboardKey="ArrowLeft" />
          <ArrowKeybind keyboardKey="ArrowRight" />
          {datePeriodGroups
            .concat([[last6MonthsLinkItem]])
            .flatMap((group) =>
              group
                .filter(([[_name, keyboardKey]]) => !!keyboardKey)
                .map(([[_name, keyboardKey], { search, onClick, isActive }]) =>
                  onClick || isActive({ site, query }) ? (
                    <Keybind
                      key={keyboardKey}
                      keyboardKey={keyboardKey}
                      type="keydown"
                      handler={onClick || closeMenu}
                      shouldIgnoreWhen={[isModifierPressed, isTyping]}
                      targetRef="document"
                    />
                  ) : (
                    <NavigateKeybind
                      key={keyboardKey}
                      keyboardKey={keyboardKey}
                      type="keydown"
                      navigateProps={{ search }}
                    />
                  )
                )
            )}
        </>
      )}
    </div>
  )
}
