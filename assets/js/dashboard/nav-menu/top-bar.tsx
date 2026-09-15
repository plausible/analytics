import React, {
  ReactNode,
  forwardRef,
  useLayoutEffect,
  useRef,
  useState
} from 'react'
import { SiteSwitcherStatic } from '../site-switcher'
import { useSiteContext } from '../site-context'
import { useUserContext } from '../user-context'
import CurrentVisitors from '../stats/current-visitors'
import classNames from 'classnames'
import { useInView } from 'react-intersection-observer'
import { FilterMenu } from './filter-menu'
import { FiltersBar } from './filters-bar'
import { DashboardPeriodPicker } from './query-periods/dashboard-period-picker'
import { SegmentMenu } from './segments/segment-menu'
import { DashboardOptionsMenu } from './dashboard-options-menu'

interface TopBarProps {
  showCurrentVisitors: boolean
}

export function TopBar({ showCurrentVisitors }: TopBarProps) {
  const site = useSiteContext()
  const user = useUserContext()
  // Shared links and embeds render no app header to take the name from.
  const headerless = !user.loggedIn || site.embedded

  // Assume in view until told otherwise, or the sticky bar flashes on load.
  const { ref: sentinelRef, inView } = useInView({
    threshold: 0,
    initialInView: true
  })
  const { fadeRef, handedOver } = useScrollHandover(!headerless)

  return (
    <>
      <div
        id="stats-container-top"
        className="col-span-full"
        ref={sentinelRef}
      />
      <TopBarStickyWrapper stuck={!inView} ref={fadeRef}>
        <TopBarInner
          showCurrentVisitors={showCurrentVisitors}
          headerless={headerless}
          handedOver={handedOver}
        />
      </TopBarStickyWrapper>
    </>
  )
}

const TopBarStickyWrapper = forwardRef<
  HTMLDivElement,
  { children: ReactNode; stuck: boolean }
>(function TopBarStickyWrapper({ children, stuck }, ref) {
  const site = useSiteContext()

  return (
    <div
      ref={ref}
      className={classNames(
        'col-span-full relative top-0 py-2 -my-3 sm:-my-4 z-10',
        !site.embedded &&
          stuck &&
          'sticky bg-gray-50 dark:bg-gray-950 before:absolute before:top-0 before:w-screen before:h-full before:bg-inherit before:shadow-[0_4px_2px_-2px_rgb(0_0_0/6%)] before:z-[-1] before:left-[calc(50%-50vw)]'
      )}
    >
      {children}
    </div>
  )
})

const HANDOVER_CLASSES =
  'motion-safe:[opacity:var(--bar-fade,1)] motion-safe:[translate:0_var(--bar-lift,0px)]'

function TopBarInner({
  showCurrentVisitors,
  headerless,
  handedOver
}: TopBarProps & { headerless: boolean; handedOver: boolean }) {
  const leftActionsRef = useRef<HTMLDivElement>(null)

  return (
    <div className="flex min-w-0 flex-nowrap items-center gap-x-1 md:gap-x-2.5 overflow-x-auto md:overflow-visible w-full touch-pan-x md:touch-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden py-1 -my-1 md:py-0 md:my-0">
      <div
        className={classNames(
          'flex shrink-0 items-center sm:gap-x-1 md:gap-x-2.5',
          HANDOVER_CLASSES
        )}
        ref={leftActionsRef}
      >
        {(headerless || handedOver) && <SiteSwitcherStatic />}
        {showCurrentVisitors && <CurrentVisitors compact={handedOver} />}
      </div>
      <div className={classNames('flex flex-1', HANDOVER_CLASSES)}>
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
      <div className="flex gap-x-1 md:gap-x-2.5 shrink-0">
        <FilterMenu />
        <SegmentMenu />
        <DashboardPeriodPicker />
        <DashboardOptionsMenu />
      </div>
    </div>
  )
}

const HEADER_SITE_NAME_ID = 'nav-site'
const FADE_OUT_END = 0.45
const FADE_IN_START = 0.55
const FADE_IN_END = 0.9
const LIFT_PX = 6
const SWAP_AT = (FADE_OUT_END + FADE_IN_START) / 2

export function fadeAt(progress: number): number {
  if (progress < FADE_OUT_END) {
    return 1 - progress / FADE_OUT_END
  }

  if (progress < FADE_IN_START) {
    return 0
  }

  return Math.min((progress - FADE_IN_START) / (FADE_IN_END - FADE_IN_START), 1)
}

export function liftAt(progress: number): number {
  const strayed = (1 - fadeAt(progress)) * LIFT_PX

  return progress < FADE_OUT_END ? -strayed : strayed
}

/**
 * Drives the fade from the scroll position, measured against the header chip
 * that names the site, so the bar has the name before the header loses it.
 * The fade goes out as custom properties to avoid a re-render per frame.
 */
function useScrollHandover(enabled: boolean) {
  const fadeRef = useRef<HTMLDivElement | null>(null)
  const [handedOver, setHandedOver] = useState(false)

  useLayoutEffect(() => {
    if (!enabled) {
      return
    }

    const headerSiteName = document.getElementById(HEADER_SITE_NAME_ID)
    if (!headerSiteName) {
      setHandedOver(true)
      return
    }

    let frame: number | null = null
    let handoverEnd = 1

    const measure = () => {
      handoverEnd = Math.max(
        headerSiteName.getBoundingClientRect().bottom + window.scrollY,
        1
      )
    }

    const paint = () => {
      frame = null

      const fadeTarget = fadeRef.current
      if (!fadeTarget) {
        return
      }

      const progress = Math.min(Math.max(window.scrollY / handoverEnd, 0), 1)

      fadeTarget.style.setProperty('--bar-fade', fadeAt(progress).toFixed(3))
      fadeTarget.style.setProperty(
        '--bar-lift',
        `${liftAt(progress).toFixed(2)}px`
      )
      setHandedOver(progress >= SWAP_AT)
    }

    const schedule = () => {
      if (frame === null) {
        frame = requestAnimationFrame(paint)
      }
    }

    const remeasure = () => {
      measure()
      schedule()
    }

    measure()
    paint()
    window.addEventListener('scroll', schedule, { passive: true })
    window.addEventListener('resize', remeasure)

    return () => {
      window.removeEventListener('scroll', schedule)
      window.removeEventListener('resize', remeasure)
      if (frame !== null) {
        cancelAnimationFrame(frame)
      }
    }
  }, [enabled])

  return { fadeRef, handedOver }
}
