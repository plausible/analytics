import React, { useState, useEffect, useRef } from 'react'
import LazyLoader from '../../components/lazy-loader'
import { Tooltip } from '../../util/tooltip'
import { useDebounce } from '../../custom-hooks'
import { useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import {
  numberShortFormatter,
  numberLongFormatter,
  percentageFormatter
} from '../../util/number-formatter'
import { RefreshIcon, CursorIcon, FolderIcon } from '../../components/icons'
import { ChevronUpDownIcon } from '@heroicons/react/20/solid'
import { FlagIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline'
import { popover } from '../../components/popover'
import { PathConnectors } from './path-connectors'
import { useExplorationData } from './exploration-state'
import { roundedPercentage } from './helpers'
import { journeyStepsEqual } from './journey'
import {
  DIRECTION,
  DIRECTION_OPTIONS,
  MAX_VISIBLE_CANDIDATES,
  MIN_GRID_COLUMNS
} from './constants'

// Column header label based on index and direction.
function columnHeader(index, direction) {
  if (index === 0) {
    return direction === DIRECTION.BACKWARD ? 'End point' : 'Starting point'
  }
  const word = direction === DIRECTION.BACKWARD ? 'before' : 'after'
  return `${index} step${index === 1 ? '' : 's'} ${word}`
}

function DirectionDropdown({ direction, onChange }) {
  const [open, setOpen] = useState(false)
  const containerRef = useRef(null)

  useEffect(() => {
    if (!open) return
    function onClickOutside(e) {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [open])

  const currentLabel = DIRECTION_OPTIONS.find(
    (o) => o.value === direction
  )?.label

  return (
    <div ref={containerRef} className="relative shrink-0">
      <button
        data-testid={`exploration-direction-${direction}`}
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-0.5 text-xs font-semibold text-gray-900 dark:text-gray-100 hover:text-gray-700 dark:hover:text-gray-200"
      >
        {currentLabel}
        <ChevronUpDownIcon className="size-3.5 shrink-0" />
      </button>

      {open && (
        <div
          className={`absolute -left-1 top-full mt-1 z-10 min-w-40 dark:!bg-gray-900 ${popover.panel.classNames.roundedSheet}`}
        >
          {DIRECTION_OPTIONS.map(({ value, label }) => (
            <button
              key={value}
              data-testid={`exploration-direction-${value}`}
              data-selected={direction === value}
              onClick={() => {
                onChange(value)
                setOpen(false)
              }}
              className={`w-full text-left text-sm rounded-md dark:hover:!bg-gray-750 data-[selected=true]:dark:!bg-gray-750 ${popover.items.classNames.navigationLink} ${popover.items.classNames.hoverLink} ${direction === value ? popover.items.classNames.selectedOption : ''}`}
            >
              {label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

function CandidateCard({
  step,
  visitors,
  isSelected,
  isDimmed,
  selectedVisitors,
  selectedConversionRate,
  stepMaxVisitors,
  colIndex,
  onSelect
}) {
  const { explorationJourneyEndEvent: journeyEndEvent } = useSiteContext()
  const isJourneyEnd = step.name === journeyEndEvent
  const isCustomEvent =
    step.name !== 'pageview' && step.name !== journeyEndEvent
  const isGoal = step.is_goal

  const visitorsToShow =
    isSelected && selectedVisitors !== null ? selectedVisitors : visitors
  const barWidth =
    isSelected && selectedConversionRate !== null
      ? Math.max(1, selectedConversionRate)
      : Math.max(1, roundedPercentage(visitors, stepMaxVisitors))

  const textColor = isDimmed
    ? 'text-gray-400 dark:text-gray-500 group-hover:text-gray-600 dark:group-hover:text-gray-400'
    : 'text-gray-900 dark:text-gray-100'

  const barBg = isJourneyEnd
    ? 'bg-gray-100 dark:bg-gray-700/50'
    : isSelected
      ? 'bg-indigo-150 group-hover:bg-indigo-150 dark:bg-indigo-500/50 dark:group-hover:bg-indigo-500/50'
      : isDimmed
        ? 'bg-indigo-50/80 dark:bg-indigo-500/10 group-hover:bg-indigo-100 dark:group-hover:bg-indigo-500/25'
        : 'bg-indigo-50 group-hover:bg-indigo-100 dark:bg-indigo-500/20 dark:group-hover:bg-indigo-500/30'

  const rowBg = isSelected
    ? 'bg-gray-100/60 dark:bg-gray-850'
    : 'hover:bg-gray-100/60 dark:hover:bg-gray-850'

  const pointer = isJourneyEnd ? 'pointer-events-none' : ''

  const onSelectHandler = isJourneyEnd ? () => {} : onSelect

  const iconClassName = `size-4 shrink-0 ${textColor}`
  const iconTooltipInfo =
    isCustomEvent || isGoal
      ? isGoal
        ? 'Goal'
        : 'Custom event'
      : step.includes_subpaths
        ? `Grouped pages: ${numberShortFormatter(step.subpaths_count)} pages with this prefix`
        : 'Pageview'

  const iconSvg =
    isCustomEvent || isGoal ? (
      <CursorIcon className={iconClassName} />
    ) : step.includes_subpaths ? (
      <FolderIcon className={iconClassName} />
    ) : null

  const iconElement = !iconSvg ? null : (
    <Tooltip info={iconTooltipInfo} containerRef={{ current: document.body }}>
      {iconSvg}
    </Tooltip>
  )

  return (
    <li data-testid="exploration-row">
      <button
        data-exploration-step={isSelected ? colIndex : undefined}
        className={`group relative w-full text-left text-sm rounded-sm overflow-hidden focus:outline-none ${rowBg} ${pointer}`}
        onClick={() => onSelectHandler(isSelected ? null : step)}
      >
        <div
          className={`absolute top-0 left-0 h-full rounded-sm transition-[width] ease-in-out ${barBg}`}
          data-testid="metric-bar"
          style={{ width: `${barWidth}%` }}
        />

        <div className="relative flex items-center justify-between gap-2 px-2 py-1.5">
          <span
            className={`flex items-center gap-2 min-w-0 ${textColor}`}
            title={step.label}
            data-testid="metric-label"
          >
            {iconElement}
            <span className="truncate">{step.label}</span>
          </span>

          <span className={`shrink-0 font-medium ${textColor}`}>
            <VisitorsMetric visitors={visitorsToShow} />
          </span>
        </div>
      </button>
    </li>
  )
}

function VisitorsMetric({ visitors }) {
  const shortNumber = numberShortFormatter(visitors)
  const longNumber = numberLongFormatter(visitors)
  const showTooltip = shortNumber !== longNumber

  if (showTooltip) {
    return (
      <Tooltip info={longNumber} containerRef={{ current: document.body }}>
        <span data-testid="metric-value">{shortNumber}</span>
      </Tooltip>
    )
  } else {
    return <span data-testid="metric-value">{shortNumber}</span>
  }
}

function ColumnEmptyState({
  active,
  filter,
  colIndex,
  direction,
  rateLimited,
  onRetry
}) {
  if (active && rateLimited) {
    return (
      <span>
        Too many requests, please wait a moment and{' '}
        <button
          onClick={onRetry}
          className="underline hover:text-gray-600 dark:hover:text-gray-300 focus:outline-none"
        >
          try again
        </button>
      </span>
    )
  }

  if (!active) {
    const prompt =
      colIndex === 1
        ? direction === DIRECTION.BACKWARD
          ? 'Select an end point to continue'
          : 'Select a starting point to continue'
        : 'Select an event to continue'

    return (
      <span className="flex flex-col items-center gap-2">
        <CursorIcon className="size-5" />
        {prompt}
      </span>
    )
  }

  if (filter) {
    return (
      <span className="flex flex-col items-center gap-2">
        <MagnifyingGlassIcon className="size-4.5" />
        No events found
      </span>
    )
  }

  return (
    <span className="flex flex-col items-center gap-2">
      <FlagIcon className="size-4.5" />
      No further steps found for the selected period and filters
    </span>
  )
}

function MaxDepthColumn({ colIndex, header }) {
  const { explorationMaxJourneySteps: maxJourneySteps } = useSiteContext()
  return (
    <div
      data-testid={`exploration-column-${colIndex}`}
      data-exploration-column={colIndex}
      className="border border-gray-200 dark:border-gray-750 rounded-lg overflow-hidden"
    >
      <div className="h-[42px] py-2 pl-4 pr-1.5 flex items-center">
        <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
          {header}
        </span>
      </div>
      <div className="h-92 flex items-center justify-center max-w-2/3 mx-auto text-center text-sm text-pretty text-gray-400 dark:text-gray-500">
        <span className="flex flex-col items-center gap-2">
          <FlagIcon className="size-4.5" />
          {`You've reached the maximum journey depth of ${maxJourneySteps} steps.`}
        </span>
      </div>
    </div>
  )
}

function ExplorationColumn({
  colIndex,
  direction,
  onDirectionChange,
  header,
  headerConversionRate,
  active,
  loading,
  loadingInBackground,
  results,
  selected,
  selectedVisitors,
  selectedConversionRate,
  maxVisitors,
  filter,
  onFilterChange,
  onSelect,
  rateLimited,
  onRetry
}) {
  const debouncedFilterChange = useDebounce((e) =>
    onFilterChange(e.target.value)
  )

  // When a step is selected but there are no candidate results,
  // synthesise a single-item list from the funnel data so
  // the selected step is still rendered in the column.
  const listItems =
    selected && results.length === 0
      ? [{ step: selected, visitors: selectedVisitors ?? 0 }]
      : results.slice(0, MAX_VISIBLE_CANDIDATES)

  const stepMaxVisitors = maxVisitors ?? results[0]?.visitors

  const showSearch = active && !selected && (results.length > 0 || filter)

  const onSelectHandler = loadingInBackground ? () => {} : onSelect

  return (
    <div
      data-testid={`exploration-column-${colIndex}`}
      data-exploration-column={colIndex}
      className="border border-gray-200 dark:border-gray-750 rounded-lg overflow-hidden"
    >
      <div className="h-[44px] py-1.5 pl-4 pr-1.5 flex items-center justify-between gap-x-2">
        {onDirectionChange ? (
          <DirectionDropdown
            direction={direction}
            onChange={onDirectionChange}
          />
        ) : (
          <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
            {header}
          </span>
        )}

        {showSearch && (
          <input
            data-testid="search-input"
            type="text"
            defaultValue={filter}
            placeholder="Search"
            onChange={debouncedFilterChange}
            className="peer max-w-48 w-full h-full py-0 text-xs dark:text-gray-100 block border-gray-300 dark:border-gray-700 rounded-md dark:bg-gray-700 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          />
        )}

        {!showSearch && headerConversionRate && (
          <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
            {headerConversionRate}
          </span>
        )}
      </div>

      {loading ? (
        <div className="h-92 flex items-center justify-center">
          <div className="mx-auto loading pt-4">
            <div></div>
          </div>
        </div>
      ) : listItems.length === 0 ? (
        <div className="h-92 flex items-center justify-center max-w-2/3 mx-auto text-center text-sm text-pretty text-gray-400 dark:text-gray-500">
          <ColumnEmptyState
            active={active}
            filter={filter}
            colIndex={colIndex}
            direction={direction}
            rateLimited={rateLimited}
            onRetry={onRetry}
          />
        </div>
      ) : (
        <ul
          data-exploration-list
          className="flex flex-col gap-y-1 px-2 pb-2 h-92 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
        >
          {listItems.map(({ step, visitors }) => (
            <CandidateCard
              key={`${step.name}:${step.label}:${step.includes_subpaths ? step.subpaths_count : 0}`}
              step={step}
              visitors={visitors}
              isSelected={!!selected && journeyStepsEqual(step, selected)}
              isDimmed={!!selected && !journeyStepsEqual(step, selected)}
              selectedVisitors={selectedVisitors}
              selectedConversionRate={selectedConversionRate}
              stepMaxVisitors={stepMaxVisitors}
              colIndex={colIndex}
              onSelect={onSelectHandler}
            />
          ))}
        </ul>
      )}
    </div>
  )
}

// Scrolls the active column into view whenever the journey length changes.
function useScrollActiveColumnIntoView(containerRef, stepsLength) {
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
                  CR: {percentageFormatter(parseFloat(overallConversionRate))}{' '}
                </span>
                <span className="text-gray-500 dark:text-gray-400">
                  ({numberShortFormatter(overallConversionVisitors)})
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

              const colSelectedVisitors =
                provisional[i]?.visitors ?? funnel[i]?.visitors ?? null
              const colSelectedConversionRate =
                provisional[i]?.conversion_rate ??
                funnel[i]?.conversion_rate ??
                null

              const colHeaderConversionRate =
                funnel[i]?.conversion_rate != null
                  ? i === 0
                    ? '100%'
                    : `${parseFloat(funnel[i].conversion_rate).toFixed(1)}%`
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
                  selected={steps[i] ?? null}
                  selectedVisitors={colSelectedVisitors}
                  selectedConversionRate={colSelectedConversionRate}
                  maxVisitors={funnel[0]?.visitors ?? null}
                  filter={colFilter}
                  onFilterChange={isActive ? setActiveFilter : () => {}}
                  onSelect={(step) => selectStep(i, step)}
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
