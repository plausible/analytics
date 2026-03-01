import React, { useMemo } from 'react'
import {
  shiftDashboardPeriod,
  getDateForShiftedPeriod
} from '../../dashboard-state'
import classNames from 'classnames'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { NavigateKeybind } from '../../keybinding'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { DashboardPeriod } from '../../dashboard-time-periods'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../../router'

const ArrowKeybind = ({
  keyboardKey
}: {
  keyboardKey: 'ArrowLeft' | 'ArrowRight'
}) => {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()

  const search = useMemo(
    () =>
      shiftDashboardPeriod({
        dashboardState,
        site,
        direction: ({ ArrowLeft: -1, ArrowRight: 1 } as const)[keyboardKey],
        keybindHint: keyboardKey
      }),
    [site, dashboardState, keyboardKey]
  )

  return (
    <NavigateKeybind
      type="keydown"
      keyboardKey={keyboardKey}
      navigateProps={{ search }}
    />
  )
}

function ArrowIcon({
  testId,
  direction,
  disabled = false
}: {
  direction: 'left' | 'right'
  disabled?: boolean
}) {
  return (
    <svg
      data-testid={testId}
      className={classNames(
        'feather size-4',
        disabled
          ? 'text-gray-400 dark:text-gray-600'
          : 'text-gray-700 dark:text-gray-300'
      )}
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
    DashboardPeriod.year,
    DashboardPeriod.month,
    DashboardPeriod.day
  ]
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  const dashboardRouteMatch = useMatch(rootRoute.path)

  if (!periodsWithArrows.includes(dashboardState.period)) {
    return null
  }

  const canGoBack =
    getDateForShiftedPeriod({ site, dashboardState, direction: -1 }) !== null
  const canGoForward =
    getDateForShiftedPeriod({ site, dashboardState, direction: 1 }) !== null

  const sharedClass =
    'flex items-center px-1 sm:px-2 dark:text-gray-100 transition-colors duration-150'
  const enabledClass = 'hover:bg-gray-100 dark:hover:bg-gray-700'
  const disabledClass = 'bg-gray-200 dark:bg-gray-850 cursor-not-allowed'

  return (
    <div
      className={classNames(
        'flex rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer focus:z-10 dark:bg-gray-750',
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
            ? shiftDashboardPeriod({
                site,
                dashboardState,
                direction: -1,
                keybindHint: null
              })
            : (search) => search
        }
      >
        <ArrowIcon
          testId="period-move-back"
          direction="left"
          disabled={!canGoBack}
        />
      </AppNavigationLink>
      <AppNavigationLink
        className={classNames(sharedClass, 'rounded-r', {
          [enabledClass]: canGoForward,
          [disabledClass]: !canGoForward
        })}
        search={
          canGoForward
            ? shiftDashboardPeriod({
                site,
                dashboardState,
                direction: 1,
                keybindHint: null
              })
            : (search) => search
        }
      >
        <ArrowIcon
          testId="period-move-forward"
          direction="right"
          disabled={!canGoForward}
        />
      </AppNavigationLink>
      {!!dashboardRouteMatch && <ArrowKeybind keyboardKey="ArrowLeft" />}
      {!!dashboardRouteMatch && <ArrowKeybind keyboardKey="ArrowRight" />}
    </div>
  )
}
