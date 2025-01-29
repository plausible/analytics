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
import { useMatch } from 'react-router-dom'
import { rootRoute } from './router'
import { Menu, Transition } from '@headlessui/react'
import { MenuSeparator, popover } from './components/popover'
import { ChevronDownIcon } from '@heroicons/react/20/solid'

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

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.activeLink,
  popover.items.classNames.disabledLink
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
    'datemenu-calendar' | 'compare-menu-calendar' | null
  >(null)
  const periodMenuButtonRef = useRef<HTMLButtonElement>(null)
  const compareMenuButtonRef = useRef<HTMLButtonElement>(null)

  const dashboardRouteMatch = useMatch(rootRoute.path)

  const closeMenu = useCallback(() => {
    setMenuVisible(null)
  }, [])

  // const toggleDateMenu = useCallback(() => {
  //   setMenuVisible((prevState) =>
  //     prevState === 'datemenu' ? null : 'datemenu'
  //   )
  // }, [])

  // const toggleDateMenuCalendar = useCallback(() => {
  //   setMenuVisible((prevState) =>
  //     prevState === 'datemenu-calendar' ? null : 'datemenu-calendar'
  //   )
  // }, [])

  // const customRangeLink: LinkItem = useMemo(
  //   () => [
  //     ['Custom Range', 'C'],
  //     {
  //       search: (s) => s,
  //       isActive: ({ query }) => query.period === QueryPeriod.custom,
  //       onClick: toggleDateMenuCalendar
  //     }
  //   ],
  //   [toggleDateMenuCalendar]
  // )

  const buttonGroups = useMemo(() => {
    const groups = getDatePeriodGroups(site)
    return groups
  }, [site])

  const compareLink: LinkItem = useMemo(
    () => getCompareLinkItem({ site, query }),
    [site, query]
  )

  useEffect(() => {
    // periodMenuButtonRef.current?.click()
    // compareMenuButtonRef.current?.click()
    closeMenu()
  }, [closeMenu, query])

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows />
      <Menu as="div" className="min-w-36 md:relative lg:w-48">
        {({ close }) => {
          const groups = buttonGroups
            .slice(0, buttonGroups.length - 1)
            .concat([
              // add Custom Range link to the last group
              buttonGroups[buttonGroups.length - 1].concat([
                [
                  ['Custom Range', 'C'],
                  {
                    search: (s) => s,
                    isActive: ({ query }) =>
                      query.period === QueryPeriod.custom,
                    onClick: (e) => {
                      // custom handler is needed to prevent
                      // the calendar from immediately closing
                      // due to Menu.Button grabbing focus
                      setMenuVisible('datemenu-calendar')
                      e.preventDefault()
                      e.stopPropagation()
                      close()
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
                      .map(
                        ([
                          [_name, keyboardKey],
                          { search, onClick, isActive }
                        ]) =>
                          onClick || isActive({ site, query }) ? (
                            <Keybind
                              key={keyboardKey}
                              keyboardKey={keyboardKey}
                              type="keydown"
                              handler={(e) => {
                                if (onClick) {
                                  onClick(e)
                                }
                              }}
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
                  <ArrowKeybind keyboardKey="ArrowRight" />
                  <ArrowKeybind keyboardKey="ArrowLeft" />
                </>
              )}
              <BlurMenuButtonOnEscape targetRef={periodMenuButtonRef} />
              <Menu.Button
                ref={periodMenuButtonRef}
                className={datemenuButtonClassname}
              >
                <DisplaySelectedPeriod />
                <DateMenuChevron />
              </Menu.Button>
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
                                onClick &&
                                ((e) => onClick(e as unknown as Event))
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

      {isComparisonEnabled(query.comparison) && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Menu as="div" className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <>
                <BlurMenuButtonOnEscape targetRef={compareMenuButtonRef} />
                <Menu.Button
                  className={datemenuButtonClassname}
                  ref={compareMenuButtonRef}
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
                  <DateMenuChevron />
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
                          className={linkClassName}
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
                        className={linkClassName}
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
                        <MenuSeparator />
                        <Menu.Item disabled={query.match_day_of_week === true}>
                          <AppNavigationLink
                            className={linkClassName}
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
                            className={linkClassName}
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
    </div>
  )
}

const datemenuButtonClassname = classNames(
  'flex items-center rounded text-sm leading-tight px-2 py-2 h-9',
  'w-full justify-between bg-white dark:bg-gray-800 shadow text-gray-800 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900'
)

const DateMenuChevron = () => (
  <ChevronDownIcon className="hidden lg:inline-block h-4 w-4 md:h-5 md:w-5 ml-1 md:ml-2 text-gray-500" />
)
