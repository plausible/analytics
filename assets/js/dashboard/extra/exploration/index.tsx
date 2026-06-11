import React, { useState, useEffect, useRef, RefObject } from 'react'
import LazyLoader from '../../components/lazy-loader'
import { Tooltip } from '../../util/tooltip'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  numberShortFormatter,
  percentageFormatter
} from '../../util/number-formatter'
import { RefreshIcon } from '../../components/icons'
import { popover } from '../../components/popover'
import { PathConnectors } from './path-connectors'
import { ExplorationColumn, MaxDepthColumn } from './exploration-column'
import { useExplorationData } from './exploration-state'
import { DIRECTION, MIN_GRID_COLUMNS, ExplorationDirection } from './constants'
import { getSelectedSuggestion } from './journey'

// Column header label based on index and direction.
function columnHeader(index: number, direction: ExplorationDirection): string {
  if (index === 0) {
    return direction === DIRECTION.BACKWARD ? 'End point' : 'Starting point'
  }
  const word = direction === DIRECTION.BACKWARD ? 'before' : 'after'
  return `${index} step${index === 1 ? '' : 's'} ${word}`
}

type PlausibleTracker = (
  event: string,
  options?: { props?: Record<string, string> }
) => void

// Fires a custom event when the user picks an entry in the first column of the
// Explore view, i.e. anchors a new journey from either a starting or end point.
function trackExploreEntrySelected(direction: ExplorationDirection): void {
  const plausible = (window as unknown as { plausible?: PlausibleTracker })
    .plausible
  if (typeof plausible === 'function') {
    plausible('Explore entry selected', {
      props: { journey_direction: direction }
    })
  }
}

// Scrolls the active column into view whenever the journey length changes.
function useScrollActiveColumnIntoView(
  containerRef: RefObject<HTMLElement>,
  stepsLength: number
) {
  const prevLengthRef = useRef(0)

  useEffect(() => {
    const el = containerRef.current
    if (!el || stepsLength === prevLengthRef.current) {
      prevLengthRef.current = stepsLength
      return
    }
    prevLengthRef.current = stepsLength

    const activeColumn = el.querySelector(
      `[data-exploration-column="${stepsLength}"]`
    )
    if (activeColumn) {
      const { left: colLeft, right: colRight } =
        activeColumn.getBoundingClientRect()
      const { left: containerLeft, right: containerRight } =
        el.getBoundingClientRect()
      if (colRight > containerRight || colLeft < containerLeft) {
        el.scrollTo({
          left: el.scrollLeft + colLeft - containerLeft,
          behavior: 'smooth'
        })
      }
    } else {
      el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' })
    }
  }, [containerRef, stepsLength])
}

export function FunnelExploration() {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [inViewport, setInViewport] = useState(false)
  const maxJourneySteps = site.explorationMaxJourneySteps

  const {
    journey,
    direction,
    activeLoading,
    layoutKey,
    rateLimited,
    selectStep,
    reset,
    retry,
    setDirection,
    setActiveFilter
  } = useExplorationData({ site, dashboardState, inViewport })

  const { steps, funnel, activeResults, activeFilter, frozen, provisional } =
    journey

  const containerRef = useRef(null)
  useScrollActiveColumnIntoView(containerRef, steps.length)

  const initialLoading = !inViewport || (steps.length === 0 && activeLoading)
  const journeyEnded =
    !activeLoading && activeResults.length === 0 && steps.length >= 1
  const activeColumnIndex = steps.length

  const numColumns = initialLoading
    ? 1
    : journeyEnded || (activeLoading && steps.length === 1)
      ? steps.length + 1
      : Math.max(steps.length + 1, MIN_GRID_COLUMNS)

  const gridColumns = Math.max(numColumns, MIN_GRID_COLUMNS)

  const noData =
    !initialLoading &&
    !activeLoading &&
    steps.length === 0 &&
    funnel.length === 0 &&
    activeResults.length === 0 &&
    !activeFilter &&
    !rateLimited

  const lastFunnelStep = funnel.length >= 2 ? funnel[funnel.length - 1] : null
  const overallConversionRate = lastFunnelStep?.conversion_rate ?? null
  const overallConversionVisitors = lastFunnelStep?.visitors ?? null

  return (
    <LazyLoader onVisible={() => setInViewport(true)}>
      <div className="flex-1 flex flex-col gap-4 pt-4">
        <div className="flex flex-wrap items-center gap-x-3">
          <h4
            data-testid="exploration-title"
            className="flex-1 text-base font-semibold dark:text-gray-100"
          >
            {funnel.length >= 2
              ? `${funnel.length}-step user journey`
              : 'Explore user journeys'}
          </h4>

          {overallConversionRate != null && (
            <div className="order-last sm:order-none w-full sm:w-auto flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
              <span>
                <span className="font-medium sm:font-semibold text-gray-700 dark:text-gray-200">
                  CR: {percentageFormatter(Number(overallConversionRate!))}{' '}
                </span>
                <span className="text-gray-500 dark:text-gray-400">
                  ({numberShortFormatter(overallConversionVisitors!)})
                </span>
              </span>
              <span className="hidden sm:inline text-gray-300 dark:text-gray-600 select-none">
                |
              </span>
            </div>
          )}

          <Tooltip
            info={<span className="whitespace-nowrap">Deselect all</span>}
            className={
              steps.length === 0 ? 'invisible pointer-events-none' : ''
            }
          >
            <button
              data-testid="exploration-deselect-all"
              onClick={reset}
              className={`${popover.toggleButton.classNames.rounded} ${popover.toggleButton.classNames.outline} justify-center !h-7 px-1.5`}
            >
              <RefreshIcon className="size-3.5" />
            </button>
          </Tooltip>
        </div>

        {noData ? (
          <div className="flex-1 flex items-center justify-center font-medium text-gray-500 dark:text-gray-400">
            No data yet
          </div>
        ) : (
          <div
            ref={containerRef}
            className="relative grid gap-6 overflow-x-auto -mx-5 px-5 -mb-3 pb-3 [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
            style={{
              gridTemplateColumns: `repeat(${gridColumns}, minmax(19rem, 1fr))`
            }}
          >
            {Array.from({ length: numColumns }, (_, i) => {
              const isActive = i === activeColumnIndex
              const isReachable = steps.length >= i

              const colFilter = isActive ? activeFilter : ''
              const colFrozen = frozen[i] ?? []

              const colResults =
                isActive && (activeResults.length > 0 || colFilter)
                  ? activeResults
                  : colFrozen
              const colLoadingInBackground =
                isActive && (initialLoading || activeLoading)
              const colLoading =
                colLoadingInBackground && (!frozen[i] || !!colFilter)

              const selected = getSelectedSuggestion({
                i,
                steps,
                provisional,
                funnel
              })

              const colHeaderConversionRate =
                funnel[i]?.conversion_rate != null
                  ? i === 0
                    ? '100%'
                    : `${Number(funnel[i].conversion_rate).toFixed(1)}%`
                  : null

              if (isActive && steps.length >= maxJourneySteps) {
                return (
                  <MaxDepthColumn
                    key={i}
                    colIndex={i}
                    header={columnHeader(i, direction)}
                  />
                )
              }

              return (
                <ExplorationColumn
                  key={i}
                  colIndex={i}
                  direction={direction}
                  onDirectionChange={i === 0 ? setDirection : undefined}
                  header={columnHeader(i, direction)}
                  headerConversionRate={colHeaderConversionRate}
                  active={isReachable}
                  loadingInBackground={colLoadingInBackground}
                  loading={colLoading}
                  results={colResults}
                  selected={selected}
                  maxVisitors={funnel[0]?.visitors ?? null}
                  filter={colFilter}
                  onFilterChange={isActive ? setActiveFilter : () => {}}
                  onSelect={(step) => {
                    if (i === 0 && step !== null) {
                      trackExploreEntrySelected(direction)
                    }
                    selectStep(i, step)
                  }}
                  rateLimited={isActive && rateLimited}
                  onRetry={retry}
                />
              )
            })}

            <PathConnectors
              containerRef={containerRef}
              steps={steps}
              layoutKey={layoutKey}
            />
          </div>
        )}
      </div>
    </LazyLoader>
  )
}

export default FunnelExploration
