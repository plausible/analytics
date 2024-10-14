/** @format */

import React, { ReactNode, useRef } from 'react'
import SiteSwitcher from '../site-switcher'
import { useSiteContext } from '../site-context'
import { useUserContext } from '../user-context'
import CurrentVisitors from '../stats/current-visitors'
import QueryPeriodPicker from '../datepicker'
import classNames from 'classnames'
import { useInView } from 'react-intersection-observer'
import { FilterMenu } from './filter-menu'

interface TopBarProps {
  showCurrentVisitors: boolean
  extraBar?: ReactNode
}

export function TopBar({ showCurrentVisitors, extraBar }: TopBarProps) {
  const site = useSiteContext()
  const user = useUserContext()
  const tooltipBoundary = useRef(null)
  const { ref, inView } = useInView({ threshold: 0 })

  return (
    <>
      <div id="stats-container-top" ref={ref} />
      <div
        className={classNames(
          'relative top-0 sm:py-3 py-2 z-10',
          !site.embedded &&
            !inView &&
            'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850'
        )}
      >
        <div className="flex items-center w-full">
          <div className="flex items-center w-full" ref={tooltipBoundary}>
            <SiteSwitcher
              site={site}
              loggedIn={user.loggedIn}
              currentUserRole={user.role}
            />
            {showCurrentVisitors && (
              <CurrentVisitors tooltipBoundary={tooltipBoundary.current} />
            )}
            <FilterMenu />
          </div>
          <QueryPeriodPicker />
        </div>
        {!!extraBar && (
          <div className="flex items-center w-full">{extraBar}</div>
        )}
      </div>
    </>
  )
}
