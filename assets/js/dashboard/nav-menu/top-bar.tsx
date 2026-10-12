import React, { ReactNode } from 'react'
import { SiteSwitcher } from '../site-switcher'
import { useSiteContext } from '../site-context'
import CurrentVisitors from '../stats/current-visitors'
import classNames from 'classnames'
import { useInView } from 'react-intersection-observer'
import { FiltersBar } from './filters-bar'
import { DashboardPeriodPicker } from './query-periods/dashboard-period-picker'
import { DashboardOptionsMenu } from './dashboard-options-menu'
import { useDashboardStateContext } from '../dashboard-state-context'

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
          'col-span-full relative top-0 py-2 -my-3 sm:-my-4 z-10',
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
  const { expandedSegment } = useDashboardStateContext()

  return (
    <div className="flex min-w-0 flex-nowrap items-center gap-x-1 overflow-x-auto md:overflow-visible w-full touch-pan-x md:touch-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden py-1 -my-1 md:py-0 md:my-0">
      <div className="flex shrink-0 items-center sm:gap-x-1 md:gap-x-2.5 empty:hidden">
        {!expandedSegment && <SiteSwitcher />}
        {showCurrentVisitors && <CurrentVisitors />}
      </div>
      <div className="flex flex-1 md:min-w-0">
        <FiltersBar />
      </div>
      <div className="flex gap-x-1 shrink-0 empty:hidden">
        {!expandedSegment && <DashboardPeriodPicker />}
        {!expandedSegment && <DashboardOptionsMenu />}
      </div>
    </div>
  )
}
