import React, { ReactNode, useEffect, useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { InformationCircleIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'
import { DashboardState } from '../../dashboard-state'
import { getStaleTime } from '../../hooks/api-client'
import { numberLongFormatter, rateFormatter } from '../../util/number-formatter'
import { Tooltip } from '../../util/tooltip'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { FunnelResponse, StepMetrics, stepMetrics } from './metrics'
import { StepOutcomes } from './outcome-box'

const FUNNEL_REPORT_ID = 'funnel'

type FunnelQueryKey = [
  typeof FUNNEL_REPORT_ID,
  { dashboardState: DashboardState; funnelName: string }
]

// A longer funnel scrolls horizontally, leaving PEEK_WIDTH_PX of the next
// column in view as a hint.
const VISIBLE_COLUMNS = 5
const COLUMN_GAP_REM = 1
const PEEK_WIDTH_PX = 24
const MIN_COLUMN_WIDTH = '12rem'

const BAR_MIN_HEIGHT = '8px'
const BAR_TOP_GAP = '0.75rem'

function gridTemplateColumns(stepCount: number): string {
  if (stepCount <= VISIBLE_COLUMNS) {
    return `repeat(${stepCount}, minmax(${MIN_COLUMN_WIDTH}, 1fr))`
  }

  const reserved = `${PEEK_WIDTH_PX}px + ${VISIBLE_COLUMNS} * ${COLUMN_GAP_REM}rem`
  const width = `calc((100% - (${reserved})) / ${VISIBLE_COLUMNS})`
  return `repeat(${stepCount}, max(${MIN_COLUMN_WIDTH}, ${width}))`
}

function fillPercent(step: StepMetrics | null | undefined): number {
  return step ? Math.max(Number(step.conversionRate), 0) : 0
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

function StepHeader({ step }: { step: StepMetrics }): ReactNode {
  return (
    <>
      <span
        className="text-xs font-medium text-gray-700 dark:text-gray-300 truncate"
        title={step.label}
      >
        {step.label}
      </span>
      <div className="flex items-baseline gap-2">
        <span className="shrink-0 text-base font-semibold text-gray-900 dark:text-gray-100">
          {rateFormatter(step.conversionRate)}
        </span>
        <span className="text-xs font-medium text-gray-500 dark:text-gray-400 truncate">
          {numberLongFormatter(step.visitors)} visitors
        </span>
      </div>
    </>
  )
}

function StepHeaderPlaceholder(): ReactNode {
  return (
    <div className="flex flex-col gap-2 h-9 animate-pulse">
      <span className="h-3 w-24 rounded-sm bg-gray-150 dark:bg-gray-800" />
      <span className="h-3 w-16 rounded-sm bg-gray-150 dark:bg-gray-800" />
    </div>
  )
}

function StepColumn({
  step,
  index,
  finalStep,
  previousFill
}: {
  step: StepMetrics | null
  index: number
  finalStep: boolean
  previousFill: number
}): ReactNode {
  const fill = fillPercent(step)

  return (
    <div
      data-testid={`funnel-step-${index}`}
      className="group/step flex flex-col"
      style={{ gap: BAR_TOP_GAP }}
    >
      <div className="relative flex flex-col gap-0.5 pl-2">
        <span className="absolute inset-y-0 left-0 w-px bg-gray-200 dark:bg-gray-750" />
        {step === null ? <StepHeaderPlaceholder /> : <StepHeader step={step} />}
      </div>

      <div className="relative flex-1 min-h-56">
        <span
          className="absolute left-0 w-px bg-gray-200 dark:bg-gray-750 transition-[bottom] duration-500 ease-out"
          style={{
            top: `-${BAR_TOP_GAP}`,
            bottom: `calc(max(${previousFill}%, ${fill}%, ${BAR_MIN_HEIGHT}) + ${BAR_TOP_GAP})`
          }}
        />
        <div
          className="absolute inset-x-0 bottom-0 rounded-t-md bg-gray-100 dark:bg-gray-800 transition-[height] duration-500 ease-out"
          style={{ height: `${previousFill}%` }}
        />
        <div
          data-testid="funnel-bar"
          className={classNames(
            'absolute inset-x-0 bottom-0 rounded-md transition-[height] duration-500 ease-out',
            'bg-linear-to-b from-indigo-200 to-indigo-300 dark:from-indigo-500/35 dark:to-indigo-500/50',
            'after:absolute after:inset-0 after:rounded-md after:transition-colors',
            'after:bg-indigo-400/0 dark:after:bg-indigo-400/15',
            'group-hover/step:after:bg-indigo-400/25 dark:group-hover/step:after:bg-indigo-400/30'
          )}
          style={{ height: `max(${fill}%, ${BAR_MIN_HEIGHT})` }}
        />
        {step !== null && (
          <StepOutcomes
            step={step}
            entryStep={index === 0}
            finalStep={finalStep}
          />
        )}
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
        className="flex-1 text-sm font-semibold dark:text-gray-100"
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
        <div className="w-full sm:w-auto flex items-center gap-2 sm:gap-3 text-xs font-medium text-gray-500 dark:text-gray-400">
          <span>{funnel.steps.length}-step funnel</span>

          <span className="text-gray-300 dark:text-gray-600 select-none">
            |
          </span>

          <div className="flex items-center gap-1">
            {funnel.strict_order ? 'Strict' : 'Sequential'}
            <Tooltip
              className="flex"
              containerRef={{ current: document.body }}
              info={
                <span>
                  {funnel.strict_order
                    ? 'No other activity is allowed between steps.'
                    : 'Other activity is allowed between steps.'}
                </span>
              }
            >
              <InformationCircleIcon className="size-3.5" />
            </Tooltip>
          </div>

          <span className="text-gray-300 dark:text-gray-600 select-none">
            |
          </span>

          <span className="flex items-baseline gap-1">
            Conversion rate:
            <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
              {rateFormatter(lastStep.conversion_rate)}
            </span>
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
  const [visible, setVisible] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)
  const funnelMeta = site.funnels.find(({ name }) => name === funnelName)

  const {
    data: funnel,
    error,
    isPending: loading
  } = useQuery<FunnelResponse, Error, FunnelResponse, FunnelQueryKey>({
    queryKey: [FUNNEL_REPORT_ID, { dashboardState, funnelName }],
    enabled: visible,
    retry: false,
    queryFn: ({ queryKey }) => {
      if (typeof funnelMeta === 'undefined') {
        throw new Error('Could not fetch the funnel. Perhaps it was deleted?')
      }

      return api.get(
        `/api/stats/${encodeURIComponent(site.domain)}/funnels/${funnelMeta.id}`,
        queryKey[1].dashboardState
      )
    },
    placeholderData: (previousData) => previousData,
    staleTime: ({ queryKey }) => {
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...queryKey[1].dashboardState
      })
    }
  })

  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollLeft = 0
    }
  }, [funnelName])

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
          <StepColumn
            key={`${funnelName}-${index}`}
            step={step}
            index={index}
            finalStep={index === columns.length - 1}
            previousFill={fillPercent(columns[index - 1])}
          />
        ))}
      </div>
    )
  }

  return (
    <LazyLoader onVisible={() => setVisible(true)}>
      <div className="flex-1 flex flex-col gap-8 pt-4">
        <FunnelHeader
          funnelName={funnelName}
          funnel={error ? null : (funnel ?? null)}
          loading={loading && !error}
        />
        {renderContent()}
      </div>
    </LazyLoader>
  )
}
