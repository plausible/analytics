import React, { ReactNode, useEffect, useRef, RefObject } from 'react'
import { rateFormatter } from '../../util/number-formatter'
import { PathConnectors } from './path-connectors'
import { ExplorationColumn, MaxDepthColumn } from './exploration-column'
import { MIN_GRID_COLUMNS, ExplorationDirection } from './constants'
import { getSelectedSuggestion, Journey, JourneyStep } from './journey'

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

// Grid of columns, one per selected step plus the column to pick the next
// step from, connected with paths between the selected steps.
export function JourneyColumns({
  journey,
  direction,
  onDirectionChange,
  columnHeader,
  initialLoading,
  activeLoading,
  rateLimited,
  failed = false,
  pageTypingAllowed = false,
  suggestionCountsOnFirstStepOnly = false,
  maxSteps,
  maxDepthMessage,
  layoutKey,
  onSelect,
  onFilterChange,
  onRetry
}: {
  journey: Journey
  direction: ExplorationDirection
  onDirectionChange?: (direction: ExplorationDirection) => void
  columnHeader: (index: number) => string
  initialLoading: boolean
  activeLoading: boolean
  rateLimited: boolean
  // Whether loading the steps to pick from failed
  failed?: boolean
  pageTypingAllowed?: boolean
  // Suggestions for later steps would otherwise show counts unrelated to the
  // steps picked before them
  suggestionCountsOnFirstStepOnly?: boolean
  maxSteps: number
  maxDepthMessage?: string
  layoutKey: number
  onSelect: (columnIndex: number, step: JourneyStep | null) => void
  onFilterChange: (filter: string) => void
  onRetry: () => void
}): ReactNode {
  const { steps, funnel, activeResults, activeFilter, frozen, provisional } =
    journey

  const containerRef = useRef(null)
  useScrollActiveColumnIntoView(containerRef, steps.length)

  const journeyEnded =
    !activeLoading && activeResults.length === 0 && steps.length >= 1
  const activeColumnIndex = steps.length

  const numColumns = initialLoading
    ? 1
    : journeyEnded || (activeLoading && steps.length === 1)
      ? steps.length + 1
      : Math.max(steps.length + 1, MIN_GRID_COLUMNS)

  const gridColumns = Math.max(numColumns, MIN_GRID_COLUMNS)

  return (
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
        const colLoading = colLoadingInBackground && (!frozen[i] || !!colFilter)

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
              : rateFormatter(funnel[i].conversion_rate)
            : null

        if (isActive && steps.length >= maxSteps) {
          return (
            <MaxDepthColumn
              key={i}
              colIndex={i}
              header={columnHeader(i)}
              message={maxDepthMessage}
            />
          )
        }

        return (
          <ExplorationColumn
            key={i}
            colIndex={i}
            direction={direction}
            onDirectionChange={i === 0 ? onDirectionChange : undefined}
            header={columnHeader(i)}
            headerConversionRate={colHeaderConversionRate}
            active={isReachable}
            loadingInBackground={colLoadingInBackground}
            loading={colLoading}
            results={colResults}
            selected={selected}
            maxVisitors={funnel[0]?.visitors ?? null}
            filter={colFilter}
            onFilterChange={isActive ? onFilterChange : () => {}}
            onSelect={(step) => onSelect(i, step)}
            rateLimited={isActive && rateLimited}
            failed={isActive && failed}
            pageTypingAllowed={pageTypingAllowed}
            showSuggestionCounts={!suggestionCountsOnFirstStepOnly || i === 0}
            onRetry={onRetry}
          />
        )
      })}

      <PathConnectors
        containerRef={containerRef}
        steps={steps}
        layoutKey={layoutKey}
      />
    </div>
  )
}
