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
  testId?: string
  direction: 'left' | 'right'
  disabled?: boolean
}) {
  return (
    <svg
      data-testid={testId}
      className={classNames(
        'size-3.5',
        disabled
          ? 'text-gray-400 dark:text-gray-500'
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

export const periodsWithArrows = [
  DashboardPeriod.year,
  DashboardPeriod.month,
  DashboardPeriod.day
]

export function MovePeriodArrows() {
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

  const arrowClass = (enabled: boolean) =>
    classNames(
      'flex items-center justify-center px-px h-full rounded-md',
      enabled
        ? 'text-gray-700 dark:text-gray-300'
        : 'text-gray-400 dark:text-gray-600 cursor-not-allowed'
    )

  return (
    <div className="flex pr-1">
      <AppNavigationLink
        className={arrowClass(canGoBack)}
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
        className={arrowClass(canGoForward)}
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
