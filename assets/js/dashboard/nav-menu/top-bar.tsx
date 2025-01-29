/** @format */

import React, { useRef } from 'react'
import SiteSwitcher from '../site-switcher'
import { useSiteContext } from '../site-context'
import { useUserContext } from '../user-context'
import CurrentVisitors from '../stats/current-visitors'
import Filters from '../filters'
import classNames from 'classnames'
import { useInView } from 'react-intersection-observer'
import { FilterMenu } from './filter-menu'
import { FiltersBar } from './filters-bar'
import { QueryPeriodsPicker } from './query-periods/query-periods-picker'

export function TopBar({
  showCurrentVisitors
}: {
  showCurrentVisitors: boolean
}) {
  const site = useSiteContext()
  const user = useUserContext()
  const { ref, inView } = useInView({ threshold: 0 })
  const { saved_segments } = site.flags
  const topBarRef = useRef<HTMLDivElement>(null)
  const leftActionsRef = useRef<HTMLDivElement>(null)
  const rightActionsRef = useRef<HTMLDivElement>(null)

  return (
    <>
      <div id="stats-container-top" ref={ref} />
      <div
        className={classNames(
          'relative top-0 py-1 sm:py-2 z-10',
          !site.embedded &&
            !inView &&
            'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850'
        )}
      >
        <div className="flex items-center w-full" ref={topBarRef}>
          {saved_segments ? (
            <>
              <div
                className="flex items-center gap-x-4 shrink-0"
                ref={leftActionsRef}
              >
                <SiteSwitcher
                  site={site}
                  loggedIn={user.loggedIn}
                  currentUserRole={user.role}
                />
                {showCurrentVisitors && (
                  <CurrentVisitors tooltipBoundary={leftActionsRef.current} />
                )}
              </div>
              <div className="flex w-full">
                <FiltersBar
                  elements={{
                    topBar: topBarRef.current,
                    leftSection: leftActionsRef.current,
                    rightSection: rightActionsRef.current
                  }}
                />
              </div>
              <div className="flex gap-x-4 shrink-0" ref={rightActionsRef}>
                <FilterMenu />
                <QueryPeriodsPicker />
              </div>
            </>
          ) : (
            <>
              <div className="flex items-center w-full" ref={leftActionsRef}>
                <SiteSwitcher
                  className="mr-2 sm:mr-4"
                  site={site}
                  loggedIn={user.loggedIn}
                  currentUserRole={user.role}
                />
                {showCurrentVisitors && (
                  <CurrentVisitors
                    className="ml-1 mr-auto"
                    tooltipBoundary={leftActionsRef.current}
                  />
                )}
                <Filters />
              </div>
              <QueryPeriodsPicker className="ml-auto pl-2" />
            </>
          )}
        </div>
      </div>
    </>
  )
}
