/** @format */

import React, { ReactNode, useRef } from 'react'
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
import { SegmentMenu } from './segments/segment-menu'
import { RoutelessSegmentModals } from '../segments/routeless-segment-modals'
import { useSegmentExpandedContext } from '../segments/segment-expanded-context'

interface TopBarProps {
  showCurrentVisitors: boolean
}

export function TopBar({ showCurrentVisitors }: TopBarProps) {
  return (
    <TopBarStickyWrapper>
      <TopBarInner showCurrentVisitors={showCurrentVisitors} />
    </TopBarStickyWrapper>
  )
}

function TopBarStickyWrapper({ children }: { children: ReactNode }) {
  const site = useSiteContext()
  const { ref, inView } = useInView({ threshold: 0 })

  return (
    <>
      <div id="stats-container-top" ref={ref} />
      <div
        className={classNames(
          'relative top-0 py-2 sm:py-3 z-10',
          !site.embedded &&
            !inView &&
            'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850'
        )}
      >
        {children}
      </div>
    </>
  )
}

function TopBarInner({ showCurrentVisitors }: TopBarProps) {
  const site = useSiteContext()
  const user = useUserContext()
  const { saved_segments } = site.flags
  const leftActionsRef = useRef<HTMLDivElement>(null)
  const { expandedSegment } = useSegmentExpandedContext()
  return (
    <>
      <div className="flex items-center w-full">
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
                <CurrentVisitors tooltipBoundaryRef={leftActionsRef} />
              )}
            </div>
            <div className="flex w-full">
              {!expandedSegment && (
                <FiltersBar
                  accessors={{
                    topBar: (filtersBarElement) =>
                      filtersBarElement?.parentElement?.parentElement,
                    leftSection: (filtersBarElement) =>
                      filtersBarElement?.parentElement?.parentElement
                        ?.firstElementChild as HTMLElement,
                    rightSection: (filtersBarElement) =>
                      filtersBarElement?.parentElement?.parentElement
                        ?.lastElementChild as HTMLElement
                  }}
                />
              )}
            </div>
            <div className="flex gap-x-4 shrink-0">
              {!expandedSegment && <FilterMenu />}
              <QueryPeriodsPicker />
              <RoutelessSegmentModals />
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
                  tooltipBoundaryRef={leftActionsRef}
                />
              )}
              <Filters />
            </div>
            <QueryPeriodsPicker className="ml-auto pl-2" />
          </>
        )}
      </div>
      {!!saved_segments && !!expandedSegment && (
        <div className="flex items-center w-full mt-3 -ml-4">
          <div className="w-0" />
          <div className="flex w-full">
            <FiltersBar
              accessors={{
                topBar: (filtersBarElement) =>
                  filtersBarElement?.parentElement?.parentElement,
                leftSection: (filtersBarElement) =>
                  filtersBarElement?.parentElement?.parentElement
                    ?.firstElementChild as HTMLElement,
                rightSection: (filtersBarElement) =>
                  filtersBarElement?.parentElement?.parentElement
                    ?.lastElementChild as HTMLElement
              }}
            />
          </div>
          <div className="flex shrink-0 gap-x-4 -mr-4">
            <FilterMenu />
            <SegmentMenu />
          </div>
        </div>
      )}
    </>
  )
}
