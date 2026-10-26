import React, { useState, ReactNode } from 'react'
import LazyLoader from '../../components/lazy-loader'
import { Tooltip } from '../../util/tooltip'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  numberShortFormatter,
  rateFormatter
} from '../../util/number-formatter'
import { RefreshIcon } from '../../components/icons'
import { popover } from '../../components/popover'
import { Button } from '../../components/button'
import { FunnelBuilderControls } from '../../funnels-context'
import { useExplorationData } from './exploration-state'
import { DIRECTION, ExplorationDirection } from './constants'
import { JourneyStep } from './journey'
import { JourneyColumns } from './journey-columns'
import { chronologicalSteps, draftInvalidReason } from './funnel-draft'
import { trackEvent } from '../../dogfood'
import { FunnelType } from '../funnel/metrics'

// Column header label based on index and direction.
function columnHeader(index: number, direction: ExplorationDirection): string {
  if (index === 0) {
    return direction === DIRECTION.BACKWARD ? 'End point' : 'Starting point'
  }
  const word = direction === DIRECTION.BACKWARD ? 'before' : 'after'
  return `${index} step${index === 1 ? '' : 's'} ${word}`
}

// Fires a custom event when the user picks an entry in the first column of the
// Explore view, i.e. anchors a new journey from either a starting or end point.
function trackExploreEntrySelected(direction: ExplorationDirection): void {
  trackEvent('Explore entry selected', { journey_direction: direction })
}

export type FunnelExplorationProps = {
  // Present when the current user can build funnels out of explorations
  funnelBuilder: FunnelBuilderControls | null
}

export function FunnelExploration({
  funnelBuilder
}: FunnelExplorationProps): ReactNode {
  const [inViewport, setInViewport] = useState(false)

  return (
    <LazyLoader onVisible={() => setInViewport(true)}>
      <JourneyExploration
        inViewport={inViewport}
        funnelBuilder={funnelBuilder}
        onBuildFunnel={(steps) =>
          // Journey steps directly follow each other, as in a strict funnel
          funnelBuilder?.start('new', { steps, funnelType: FunnelType.strict })
        }
      />
    </LazyLoader>
  )
}

function JourneyExploration({
  inViewport,
  funnelBuilder,
  onBuildFunnel
}: {
  inViewport: boolean
  funnelBuilder: FunnelBuilderControls | null
  onBuildFunnel: (steps: JourneyStep[]) => void
}): ReactNode {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const maxJourneySteps = site.explorationMaxJourneySteps
  const [minFunnelSteps, maxFunnelSteps] = site.funnelStepsRange

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

  const { steps, funnel, activeResults, activeFilter } = journey

  const initialLoading = !inViewport || (steps.length === 0 && activeLoading)

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

  const funnelSteps = chronologicalSteps(steps, direction)
  const saveAsFunnelInvalidReason = draftInvalidReason(funnelSteps, {
    minSteps: minFunnelSteps,
    maxSteps: maxFunnelSteps,
    journeyEndEvent: site.explorationJourneyEndEvent
  })

  return (
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
                CR: {rateFormatter(overallConversionRate)}{' '}
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

        {funnelBuilder &&
          steps.length > 0 &&
          (saveAsFunnelInvalidReason !== null ? (
            <Tooltip info={saveAsFunnelInvalidReason}>
              <Button
                theme="secondary"
                size="sm"
                className="!h-7"
                disabled
                data-testid="exploration-save-as-funnel"
              >
                Save as funnel
              </Button>
            </Tooltip>
          ) : (
            <Button
              theme="secondary"
              size="sm"
              className="!h-7"
              data-testid="exploration-save-as-funnel"
              onClick={() => onBuildFunnel(funnelSteps)}
            >
              Save as funnel
            </Button>
          ))}

        <Tooltip
          info={<span className="whitespace-nowrap">Deselect all</span>}
          className={steps.length === 0 ? 'invisible pointer-events-none' : ''}
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
        <JourneyColumns
          journey={journey}
          direction={direction}
          onDirectionChange={setDirection}
          columnHeader={(index) => columnHeader(index, direction)}
          initialLoading={initialLoading}
          activeLoading={activeLoading}
          rateLimited={rateLimited}
          maxSteps={maxJourneySteps}
          layoutKey={layoutKey}
          onSelect={(index, step) => {
            if (index === 0 && step !== null) {
              trackExploreEntrySelected(direction)
            }
            selectStep(index, step)
          }}
          onFilterChange={setActiveFilter}
          onRetry={retry}
        />
      )}
    </div>
  )
}

export { FunnelBuilder } from './funnel-builder'

export default FunnelExploration
