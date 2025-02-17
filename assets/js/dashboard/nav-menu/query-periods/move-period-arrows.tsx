/* @format */
import React, { useMemo } from 'react'
import { shiftQueryPeriod, getDateForShiftedPeriod } from '../../query'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { NavigateKeybind } from '../../keybinding'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { QueryPeriod } from '../../query-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'

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

export function MovePeriodArrows({ className }: { className?: string }) {
  const periodsWithArrows = [
    QueryPeriod.year,
    QueryPeriod.month,
    QueryPeriod.day
  ]
  const { query } = useQueryContext()
  const site = useSiteContext()
  const dashboardRouteMatch = useMatch(rootRoute.path)

  if (!periodsWithArrows.includes(query.period)) {
    return null
  }

  const canGoBack =
    getDateForShiftedPeriod({ site, query, direction: -1 }) !== null
  const canGoForward =
    getDateForShiftedPeriod({ site, query, direction: 1 }) !== null

  const sharedClass = 'flex items-center px-1 sm:px-2 dark:text-gray-100'
  const enabledClass = 'hover:bg-gray-100 dark:hover:bg-gray-900'
  const disabledClass = 'bg-gray-300 dark:bg-gray-950 cursor-not-allowed'

  return (
    <div
      className={classNames(
        'flex rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer focus:z-10 dark:bg-gray-800',
        className
      )}
    >
      <AppNavigationLink
        className={classNames(
          sharedClass,
          'rounded-l border-gray-300 dark:border-gray-500 focus:z-10',
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
        className={classNames(sharedClass, 'rounded-r', {
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
      {!!dashboardRouteMatch && <ArrowKeybind keyboardKey="ArrowLeft" />}
      {!!dashboardRouteMatch && <ArrowKeybind keyboardKey="ArrowRight" />}
    </div>
  )
}
