import React, { ReactNode, useEffect, useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { InformationCircleIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'
import { DashboardState } from '../../dashboard-state'
import { isComparisonEnabled } from '../../dashboard-time-periods'
import { getStaleTime } from '../../hooks/api-client'
import {
  formatDateRangeLabel,
  MetricValueTooltipContent
} from '../../stats/breakdowns'
import { ChangeArrow } from '../../stats/reports/change-arrow'
import { numberLongFormatter, rateFormatter } from '../../util/number-formatter'
import { Tooltip } from '../../util/tooltip'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import {
  FunnelResponse,
  StepMetrics,
  StepValues,
  conversionRateChange,
  stepMetrics
} from './metrics'
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
const MIN_BAR_WIDTH = '12rem'

const BAR_GAP_REM = 0.5
const BAR_MIN_HEIGHT = '8px'
const BAR_TOP_GAP = '0.75rem'

function gridTemplateColumns(stepCount: number, comparing: boolean): string {
  const minWidth = comparing
    ? `calc(2 * ${MIN_BAR_WIDTH} + ${BAR_GAP_REM}rem)`
    : MIN_BAR_WIDTH

  if (stepCount <= VISIBLE_COLUMNS) {
    return `repeat(${stepCount}, minmax(${minWidth}, 1fr))`
  }

  const reserved = `${PEEK_WIDTH_PX}px + ${VISIBLE_COLUMNS} * ${COLUMN_GAP_REM}rem`
  const width = `calc((100% - (${reserved})) / ${VISIBLE_COLUMNS})`
  return `repeat(${stepCount}, max(${minWidth}, ${width}))`
}

function fillPercent(values: StepValues | null | undefined): number {
  return values ? Math.max(Number(values.conversionRate), 0) : 0
}

function showingComparison(
  step: StepMetrics | null | undefined,
  comparing: boolean
): boolean {
  return step ? step.comparison !== null : comparing
}

function verticalLineBottom(heights: number[]): string {
  const tops = [...heights.map((height) => `${height}%`), BAR_MIN_HEIGHT]
  return `calc(max(${tops.join(', ')}) + ${BAR_TOP_GAP})`
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

function ConversionChange({
  current,
  previous
}: {
  current: string
  previous: string
}): ReactNode {
  return (
    <ChangeArrow
      metric="conversion_rate"
      change={conversionRateChange(current, previous)}
      className="shrink-0 text-xs font-medium text-gray-500 dark:text-gray-100"
    />
  )
}

function PeriodStats({
  values,
  change,
  muted
}: {
  values: StepValues
  change?: ReactNode
  muted?: boolean
}): ReactNode {
  return (
    <div
      className={classNames(
        'flex flex-col min-w-0 flex-1',
        muted && 'text-gray-500/80 dark:text-gray-400'
      )}
    >
      <span className="flex items-baseline gap-1">
        <span
          className={classNames(
            'shrink-0 text-base font-semibold',
            !muted && 'text-gray-900 dark:text-gray-100'
          )}
        >
          {rateFormatter(values.conversionRate)}
        </span>
        {change}
      </span>
      <span
        className={classNames(
          'text-xs font-medium truncate',
          !muted && 'text-gray-500 dark:text-gray-400'
        )}
      >
        {numberLongFormatter(values.visitors)} visitors
      </span>
    </div>
  )
}

function StepHeader({
  step,
  entryStep
}: {
  step: StepMetrics
  entryStep: boolean
}): ReactNode {
  return (
    <>
      <span
        className="text-xs font-medium text-gray-700 dark:text-gray-300 truncate"
        title={step.label}
      >
        {step.label}
      </span>
      <div className="flex">
        <PeriodStats
          values={step}
          change={
            step.comparison && !entryStep ? (
              <ConversionChange
                current={step.conversionRate}
                previous={step.comparison.conversionRate}
              />
            ) : undefined
          }
        />
        {step.comparison && <PeriodStats values={step.comparison} muted />}
      </div>
    </>
  )
}

function MetricPlaceholder(): ReactNode {
  return (
    <div className="flex flex-col gap-2 flex-1">
      <span className="h-3 w-16 rounded-sm bg-gray-150 dark:bg-gray-800" />
      <span className="h-3 w-20 rounded-sm bg-gray-150 dark:bg-gray-800" />
    </div>
  )
}

function StepHeaderPlaceholder({
  comparing
}: {
  comparing: boolean
}): ReactNode {
  return (
    <div className="flex flex-col gap-2 animate-pulse">
      <span className="h-3 w-24 rounded-sm bg-gray-150 dark:bg-gray-800" />
      <div className="flex">
        <MetricPlaceholder />
        {comparing && <MetricPlaceholder />}
      </div>
    </div>
  )
}

function StepBar({
  values,
  previousFill,
  entryStep,
  finalStep,
  previousPeriod
}: {
  values: StepValues | null
  previousFill: number
  entryStep: boolean
  finalStep: boolean
  previousPeriod?: boolean
}): ReactNode {
  return (
    <div className="group/bar relative flex-1">
      <div
        className="absolute inset-x-0 bottom-0 rounded-t-md bg-gray-100 dark:bg-gray-800 transition-[height] duration-500 ease-out"
        style={{ height: `${previousFill}%` }}
      />
      <div
        data-testid={previousPeriod ? 'funnel-comparison-bar' : 'funnel-bar'}
        className={classNames(
          'absolute inset-x-0 bottom-0 rounded-md transition-[height] duration-500 ease-out',
          previousPeriod
            ? 'bg-indigo-100 dark:bg-indigo-500/30'
            : 'bg-linear-to-b from-indigo-300 to-indigo-400 dark:from-indigo-500/60 dark:to-indigo-500/90',
          'after:absolute after:inset-0 after:rounded-md after:transition-colors',
          previousPeriod
            ? 'after:bg-indigo-200/0 dark:after:bg-indigo-400/0 group-hover/bar:after:bg-indigo-200/15 dark:group-hover/bar:after:bg-indigo-400/5'
            : 'after:bg-indigo-500/0 dark:after:bg-indigo-400/0 group-hover/bar:after:bg-indigo-500/10 dark:group-hover/bar:after:bg-indigo-400/15'
        )}
        style={{ height: `max(${fillPercent(values)}%, ${BAR_MIN_HEIGHT})` }}
      />
      {values !== null && (
        <StepOutcomes
          values={values}
          entryStep={entryStep}
          finalStep={finalStep}
          previousPeriod={previousPeriod}
        />
      )}
    </div>
  )
}

function StepColumn({
  step,
  previousStep,
  index,
  finalStep,
  comparing
}: {
  step: StepMetrics | null
  previousStep: StepMetrics | null | undefined
  index: number
  finalStep: boolean
  comparing: boolean
}): ReactNode {
  const paired = showingComparison(step, comparing)

  const previousFill = fillPercent(previousStep)
  const previousComparisonFill = fillPercent(previousStep?.comparison)

  const heights = [previousFill, fillPercent(step)]
  if (paired) {
    heights.push(previousComparisonFill, fillPercent(step?.comparison))
  }

  return (
    <div
      data-testid={`funnel-step-${index}`}
      className="flex flex-col"
      style={{ gap: BAR_TOP_GAP }}
    >
      <div className="relative flex flex-col gap-0.5 pl-2">
        <span className="absolute inset-y-0 left-0 w-px bg-gray-200 dark:bg-gray-750" />
        {step === null ? (
          <StepHeaderPlaceholder comparing={paired} />
        ) : (
          <StepHeader step={step} entryStep={index === 0} />
        )}
      </div>

      <div className="relative flex-1 min-h-56">
        <span
          className="absolute left-0 w-px bg-gray-200 dark:bg-gray-750 transition-[bottom] duration-500 ease-out"
          style={{
            top: `-${BAR_TOP_GAP}`,
            bottom: verticalLineBottom(heights)
          }}
        />
        <div
          className="absolute inset-0 flex"
          style={{ gap: paired ? `${BAR_GAP_REM}rem` : undefined }}
        >
          <StepBar
            values={step}
            previousFill={previousFill}
            entryStep={index === 0}
            finalStep={finalStep}
          />
          {paired && (
            <StepBar
              values={step?.comparison ?? null}
              previousFill={previousComparisonFill}
              entryStep={index === 0}
              finalStep={finalStep}
              previousPeriod
            />
          )}
        </div>
      </div>
    </div>
  )
}

function ConversionRateSummary({
  current,
  previous,
  dateRange,
  comparisonDateRange
}: {
  current: string
  previous: string | null
  dateRange: [string, string] | undefined
  comparisonDateRange: [string, string] | null | undefined
}): ReactNode {
  const rate = (
    <span className="flex items-baseline gap-1">
      <span className="shrink-0">Conversion rate:</span>
      <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
        {rateFormatter(current)}
      </span>
      {previous && <ConversionChange current={current} previous={previous} />}
    </span>
  )

  if (!previous || !dateRange || !comparisonDateRange) {
    return rate
  }

  return (
    <Tooltip
      className="flex"
      containerRef={{ current: document.body }}
      info={
        <MetricValueTooltipContent
          value={Number(current)}
          comparison={{ value: Number(previous) }}
          metric="conversion_rate"
          metricLabel="Conversion rate"
          dateRangeLabel={formatDateRangeLabel(dateRange)}
          comparisonDateRangeLabel={formatDateRangeLabel(comparisonDateRange)}
        />
      }
    >
      {rate}
    </Tooltip>
  )
}

function FunnelHeader({
  funnelName,
  funnel,
  steps,
  loading
}: {
  funnelName: string
  funnel: FunnelResponse | null
  steps: StepMetrics[] | null
  loading: boolean
}): ReactNode {
  const lastStep = steps?.[steps.length - 1] ?? null

  return (
    <div className="sm:h-7 flex flex-wrap items-baseline gap-x-3">
      <h4
        data-testid="funnel-title"
        className="grow basis-auto min-w-0 truncate text-sm font-semibold dark:text-gray-100"
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
        <div className="overflow-x-auto">
          <div className="w-full sm:w-auto flex gap-2 sm:gap-3 text-xs font-medium text-gray-500 dark:text-gray-400 items-baseline">
            <span className="shrink-0">{funnel.steps.length}-step funnel</span>

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

            <ConversionRateSummary
              current={lastStep.conversionRate}
              previous={lastStep.comparison?.conversionRate ?? null}
              dateRange={funnel.date_range}
              comparisonDateRange={funnel.comparison_date_range}
            />
          </div>
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
  const comparing = isComparisonEnabled(dashboardState.comparison)

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
    placeholderData: (previousData) =>
      previousData != null && Boolean(previousData.comparison) === comparing
        ? previousData
        : undefined,
    staleTime: ({ queryKey }) => {
      return getStaleTime({
        siteTimezoneOffset: site.offset,
        siteStatsBegin: site.statsBegin,
        ...queryKey[1].dashboardState
      })
    }
  })

  const visibleFunnel = error ? null : (funnel ?? null)
  const steps = visibleFunnel ? stepMetrics(visibleFunnel) : null

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

    const columns: (StepMetrics | null)[] = steps
      ? steps
      : new Array(funnelMeta?.steps_count || VISIBLE_COLUMNS).fill(null)

    return (
      <div
        ref={containerRef}
        data-testid="funnel-steps"
        className="relative flex-1 grid overflow-x-auto -mx-5 px-5 -mb-3 pb-3 [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
        style={{
          gap: `${COLUMN_GAP_REM}rem`,
          gridTemplateColumns: gridTemplateColumns(
            columns.length,
            showingComparison(columns[0], comparing)
          )
        }}
      >
        {columns.map((step, index) => (
          <StepColumn
            key={`${funnelName}-${index}`}
            step={step}
            previousStep={columns[index - 1]}
            index={index}
            finalStep={index === columns.length - 1}
            comparing={comparing}
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
          funnel={visibleFunnel}
          steps={steps}
          loading={loading && !error}
        />
        {renderContent()}
      </div>
    </LazyLoader>
  )
}
