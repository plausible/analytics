import React, { ReactNode, useRef } from 'react'
import { SiteSwitcher } from '../site-switcher'
import { useSiteContext } from '../site-context'
import CurrentVisitors from '../stats/current-visitors'
import classNames from 'classnames'
import { useInView } from 'react-intersection-observer'
import { FilterMenu } from './filter-menu'
import { FiltersBar } from './filters-bar'
import { DashboardPeriodPicker } from './query-periods/dashboard-period-picker'
import { SegmentMenu } from './segments/segment-menu'

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
      <div id="stats-container-top" className="col-span-full" ref={ref} />
      <div
        className={classNames(
          'col-span-full relative top-0 py-2 sm:py-3 -my-3 sm:-my-4 z-10',
          !site.embedded &&
            !inView &&
            'sticky bg-gray-50 dark:bg-gray-950 before:absolute before:top-0 before:w-screen before:h-full before:bg-inherit before:shadow-[0_4px_2px_-2px_rgb(0_0_0/6%)] before:z-[-1] before:left-[calc(50%-50vw)]'
        )}
      >
        {children}
      </div>
    </>
  )
}

function TopBarInner({ showCurrentVisitors }: TopBarProps) {
  const leftActionsRef = useRef<HTMLDivElement>(null)

  return (
    <div className="flex items-center w-full">
      <div className="flex items-center gap-x-5 shrink-0" ref={leftActionsRef}>
        <SiteSwitcher />
        {showCurrentVisitors && (
          <CurrentVisitors tooltipBoundaryRef={leftActionsRef} />
        )}
      </div>
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
      <div className="flex gap-x-4 shrink-0">
        <FilterMenu />
        <SegmentMenu />
        <DashboardPeriodPicker />
      </div>
    </div>
  )
}
