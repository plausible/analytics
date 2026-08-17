import React, { ReactNode, useEffect, useRef, useState } from 'react'
import { ArrowDownRightIcon, ArrowRightIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'
import {
  numberLongFormatter,
  numberShortFormatter,
  rateFormatter
} from '../../util/number-formatter'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  FunnelResponse,
  StepMetrics,
  StepOutcome,
  stepMetrics
} from './metrics'

// A longer funnel scrolls horizontally, leaving PEEK_WIDTH_PX of the next
// column in view as a hint.
const VISIBLE_COLUMNS = 4
const COLUMN_GAP_REM = 0.75
const PEEK_WIDTH_PX = 24
const MIN_COLUMN_WIDTH = '13rem'
const LABEL_HALF_HEIGHT_PX = 25
// A label centres on the top edge of its bar, but never comes closer than this
// to the bottom of the bar, so a step that converts almost nobody keeps its
// label clear of the card edge.
const LABEL_FLOOR_GAP_PX = 6

function gridTemplateColumns(stepCount: number): string {
  if (stepCount <= VISIBLE_COLUMNS) {
    return `repeat(${stepCount}, minmax(${MIN_COLUMN_WIDTH}, 1fr))`
  }

  const reserved = `${PEEK_WIDTH_PX}px + ${VISIBLE_COLUMNS} * ${COLUMN_GAP_REM}rem`
  const width = `calc((100% - (${reserved})) / ${VISIBLE_COLUMNS})`
  return `repeat(${stepCount}, max(${MIN_COLUMN_WIDTH}, ${width}))`
}

function userFacingMessage(error: Error): string | null {
  if (!(error instanceof api.ApiError)) {
    return null
  }

  const { payload } = error
  const written =
    typeof payload === 'object' &&
    payload !== null &&
    'level' in payload &&
    payload.level === 'normal'

  return written && error.message ? error.message : null
}

function StepOutcomeRow({
  outcome,
  dropoff
}: {
  outcome: StepOutcome
  dropoff: boolean
}): ReactNode {
  const Icon = dropoff ? ArrowDownRightIcon : ArrowRightIcon
  const color = dropoff
    ? 'text-gray-500 dark:text-gray-400'
    : 'text-gray-900 dark:text-gray-100'

  return (
    <div className={classNames('flex items-center gap-1.5', color)}>
      <Icon className="size-3 shrink-0 stroke-2" />
      <span>
        {numberLongFormatter(outcome.visitors)} ({rateFormatter(outcome.rate)})
      </span>
    </div>
  )
}

function StepHeader({ step }: { step: StepMetrics }): ReactNode {
  return (
    <>
      <span
        className="text-xs font-medium sm:font-semibold text-gray-700 dark:text-gray-200 truncate"
        title={step.label}
      >
        {step.label}
      </span>
      <div className="flex items-center gap-2">
        <span className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          {numberLongFormatter(step.visitors)}
        </span>
        <span className="shrink-0 rounded-md px-1 py-0.5 text-xs font-semibold border border-gray-200 dark:border-gray-750 text-indigo-600 dark:text-indigo-400">
          {rateFormatter(step.conversionRate)}
        </span>
      </div>
    </>
  )
}

function StepHeaderPlaceholder(): ReactNode {
  return (
    <div className="flex flex-col gap-2 h-11">
      <span className="h-3 w-24 rounded-sm bg-gray-150 dark:bg-gray-800" />
      <span className="h-3 w-16 rounded-sm bg-gray-150 dark:bg-gray-800" />
    </div>
  )
}

function StepColumn({
  step,
  index
}: {
  step: StepMetrics | null
  index: number
}): ReactNode {
  const fill = step === null ? 0 : Math.max(Number(step.conversionRate), 0)

  return (
    <div
      data-testid={`funnel-step-${index}`}
      className="flex flex-col border border-gray-200 dark:border-gray-750 rounded-lg overflow-hidden"
    >
      <div
        className={classNames(
          'flex flex-col gap-0.5 px-4 pt-3 pb-2',
          step === null && 'animate-pulse'
        )}
      >
        {step === null ? <StepHeaderPlaceholder /> : <StepHeader step={step} />}
      </div>

      <div className="flex-1 min-h-64 px-2 pt-8 pb-2">
        <div className="relative h-full">
          <div
            data-testid="funnel-bar"
            className="absolute inset-x-0 bottom-0 rounded-sm bg-linear-to-b from-indigo-200 to-indigo-100 dark:from-indigo-500/50 dark:to-indigo-500/35 transition-[height] duration-500 ease-out"
            style={{ height: `max(${fill}%, 8px)` }}
          />
          <div
            className="absolute inset-x-0 flex justify-center translate-y-1/2 transition-[bottom] duration-500 ease-out"
            style={{
              bottom: `max(${fill}%, ${LABEL_HALF_HEIGHT_PX + LABEL_FLOOR_GAP_PX}px)`
            }}
          >
            {step !== null && (
              <div className="flex flex-col gap-1 max-w-full px-2.5 py-1.5 rounded-md text-xs font-medium whitespace-nowrap border border-gray-200 dark:border-gray-750 bg-white dark:bg-gray-825 shadow-sm opacity-100 transition-opacity duration-300 starting:opacity-0">
                <StepOutcomeRow outcome={step.continued} dropoff={false} />
                <StepOutcomeRow outcome={step.droppedOff} dropoff={true} />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function FunnelHeader({
  funnelName,
  funnel,
  loading
}: {
  funnelName: string
  funnel: FunnelResponse | null
  loading: boolean
}): ReactNode {
  const lastStep = funnel ? funnel.steps[funnel.steps.length - 1] : null

  return (
    <div className="sm:h-7 flex flex-wrap items-center gap-x-3">
      <h4
        data-testid="funnel-title"
        className="flex-1 text-base font-semibold dark:text-gray-100"
      >
        {funnelName}
      </h4>

      {!funnel && loading && (
        <div className="w-full sm:w-auto flex items-center gap-2 sm:gap-3 animate-pulse">
          <span className="h-3 w-28 rounded-sm bg-gray-150 dark:bg-gray-800" />
          <span className="h-3 w-20 rounded-sm bg-gray-150 dark:bg-gray-800" />
        </div>
      )}

      {funnel && lastStep && (
        <div className="w-full sm:w-auto flex items-center gap-2 sm:gap-3 text-xs text-gray-500 dark:text-gray-400">
          <span className="font-medium sm:font-semibold text-gray-700 dark:text-gray-200">
            {funnel.steps.length}-step{' '}
            {funnel.strict_order ? 'strict' : 'flexible'} funnel
          </span>

          <span className="text-gray-300 dark:text-gray-600 select-none">
            |
          </span>

          <span>
            <span className="font-medium sm:font-semibold text-gray-700 dark:text-gray-200">
              CR: {rateFormatter(lastStep.conversion_rate)}
            </span>{' '}
            <span>({numberShortFormatter(lastStep.visitors)})</span>
          </span>
        </div>
      )}
    </div>
  )
}

export default function Funnel({
  funnelName
}: {
  funnelName: string
}): ReactNode {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [loading, setLoading] = useState(true)
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState<Error | undefined>(undefined)
  const [funnel, setFunnel] = useState<FunnelResponse | null>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const funnelMeta = site.funnels.find(({ name }) => name === funnelName)

  useEffect(() => {
    if (!visible) {
      return
    }

    setLoading(true)
    ;(async () => {
      try {
        setFunnel(await fetchFunnel())
        setError(undefined)
      } catch (error) {
        setError(error as Error)
      } finally {
        setLoading(false)
      }
    })()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardState, funnelName, visible])

  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollLeft = 0
    }
  }, [funnelName])

  function fetchFunnel(): Promise<FunnelResponse> {
    if (typeof funnelMeta === 'undefined') {
      return Promise.reject(
        new Error('Could not fetch the funnel. Perhaps it was deleted?')
      )
    }

    return api.get(
      `/api/stats/${encodeURIComponent(site.domain)}/funnels/${funnelMeta.id}`,
      dashboardState
    )
  }

  function renderError(error: Error): ReactNode {
    if (error.name === 'AbortError') {
      return null
    }

    const message = userFacingMessage(error)

    return (
      <div className="flex-1 flex flex-col items-center justify-center text-center gap-1">
        <div className="text-base font-semibold text-gray-900 dark:text-gray-100">
          {message
            ? 'This funnel can’t be shown'
            : 'This funnel couldn’t be loaded'}
        </div>
        <div className="text-sm text-gray-500 dark:text-gray-400">
          {message ?? 'Refresh the page to try again.'}
        </div>
      </div>
    )
  }

  function renderContent(): ReactNode {
    if (error) {
      return renderError(error)
    }

    const columns: (StepMetrics | null)[] = funnel
      ? stepMetrics(funnel)
      : new Array(funnelMeta?.steps_count || VISIBLE_COLUMNS).fill(null)

    return (
      <div
        ref={containerRef}
        data-testid="funnel-steps"
        className="relative flex-1 grid overflow-x-auto -mx-5 px-5 -mb-3 pb-3 [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
        style={{
          gap: `${COLUMN_GAP_REM}rem`,
          gridTemplateColumns: gridTemplateColumns(columns.length)
        }}
      >
        {columns.map((step, index) => (
          <StepColumn key={index} step={step} index={index} />
        ))}
      </div>
    )
  }

  return (
    <LazyLoader onVisible={() => setVisible(true)}>
      <div className="flex-1 flex flex-col gap-4 pt-4">
        <FunnelHeader
          funnelName={funnelName}
          funnel={error ? null : funnel}
          loading={loading && !error}
        />
        {renderContent()}
      </div>
    </LazyLoader>
  )
}
