import React, { useState, useEffect, useRef, ReactNode, RefObject } from 'react'
import { Tooltip } from '../../util/tooltip'
import { useSiteContext } from '../../site-context'
import { useDebounce } from '../../custom-hooks'
import {
  numberShortFormatter,
  numberLongFormatter,
  roundedNumberFormatter
} from '../../util/number-formatter'
import { CursorIcon, FolderIcon } from '../../components/icons'
import { popover, SelectedCheckmark } from '../../components/popover'
import {
  ChevronUpDownIcon,
  EllipsisHorizontalIcon
} from '@heroicons/react/20/solid'
import { FlagIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline'
import {
  journeyStepsEqual,
  JourneyStep,
  JourneySuggestion,
  SelectedSuggestion
} from './journey'
import {
  DIRECTION,
  DIRECTION_OPTIONS,
  INITIAL_VISIBLE_CANDIDATES,
  SHOW_MORE_INCREMENT,
  ExplorationDirection
} from './constants'

export function InlineDropdown<T extends string>({
  value,
  options,
  onChange,
  testId,
  align = 'left'
}: {
  value: T
  options: { value: T; label: string }[]
  onChange: (value: T) => void
  testId: string
  align?: 'left' | 'right'
}): ReactNode {
  const [open, setOpen] = useState(false)
  const containerRef: RefObject<HTMLDivElement> = useRef(null)

  useEffect(() => {
    if (!open) return
    function onClickOutside(e: Event) {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as HTMLElement)
      ) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [open])

  const currentLabel = options.find((o) => o.value === value)?.label

  return (
    <>
      {open && (
        <div
          aria-hidden="true"
          className={popover.backdrop.classNames.transparent}
        />
      )}
      <div ref={containerRef} className="relative shrink-0">
        <button
          data-testid={`${testId}-${value}`}
          aria-expanded={open}
          onClick={() => setOpen((o) => !o)}
          className={`${popover.toggleButton.classNames.aboveBackdrop} flex items-center gap-0.5 text-xs font-semibold text-gray-900 dark:text-gray-100 hover:text-gray-700 dark:hover:text-gray-200`}
        >
          {currentLabel}
          <ChevronUpDownIcon className="size-3.5 shrink-0" />
        </button>

        {open && (
          <div
            className={`absolute ${align === 'left' ? '-left-1' : '-right-1'} top-full mt-1 z-10 min-w-44 dark:!bg-gray-900 ${popover.panel.classNames.roundedSheet}`}
          >
            {options.map((option) => (
              <button
                key={option.value}
                data-testid={`${testId}-${option.value}`}
                data-selected={value === option.value}
                onClick={() => {
                  onChange(option.value)
                  setOpen(false)
                }}
                className={`w-full text-left text-sm rounded-md dark:hover:!bg-gray-750 data-[selected=true]:dark:!bg-gray-750 ${popover.items.classNames.navigationLink} ${popover.items.classNames.hoverLink} ${value === option.value ? popover.items.classNames.selectedOption : ''}`}
              >
                {option.label}
                <SelectedCheckmark selected={value === option.value} />
              </button>
            ))}
          </div>
        )}
      </div>
    </>
  )
}

const GOAL_KIND_LABELS = {
  plain: 'Goal',
  scroll: 'Scroll depth goal',
  props: 'Goal with custom properties',
  revenue: 'Revenue goal'
}

function CandidateCard({
  step,
  visitors,
  selected,
  stepMaxVisitors,
  colIndex,
  showCount,
  onSelect
}: {
  step: JourneyStep
  visitors: number
  selected: SelectedSuggestion | null
  stepMaxVisitors: number
  colIndex: number
  // The selected step always shows its count, once known
  showCount: boolean
  onSelect: (step: JourneyStep | null) => void
}): ReactNode {
  const { explorationJourneyEndEvent: journeyEndEvent } = useSiteContext()

  const isSelected = !!selected && journeyStepsEqual(step, selected.step)
  const isDimmed = !!selected && !journeyStepsEqual(step, selected.step)

  const isCustomEvent =
    step.name !== 'pageview' && step.name !== journeyEndEvent
  const isGoal = step.is_goal

  const visitorsToShow =
    isSelected && selected.visitors !== null
      ? selected.visitors
      : showCount
        ? visitors
        : null

  const barWidth =
    isSelected && selected.conversion_rate !== null
      ? Math.max(1, Number(selected.conversion_rate))
      : showCount
        ? Math.max(
            1,
            Number(roundedNumberFormatter((visitors / stepMaxVisitors) * 100))
          )
        : null

  const textColor = isDimmed
    ? 'text-gray-400 dark:text-gray-500 group-hover:text-gray-600 dark:group-hover:text-gray-400'
    : 'text-gray-900 dark:text-gray-100'

  const barBg = isSelected
    ? 'bg-indigo-150 group-hover:bg-indigo-150 dark:bg-indigo-500/50 dark:group-hover:bg-indigo-500/50'
    : isDimmed
      ? 'bg-indigo-50/80 dark:bg-indigo-500/10 group-hover:bg-indigo-100 dark:group-hover:bg-indigo-500/25'
      : 'bg-indigo-50 group-hover:bg-indigo-100 dark:bg-indigo-500/20 dark:group-hover:bg-indigo-500/30'

  const rowBg = isSelected
    ? 'bg-gray-100/60 dark:bg-gray-850'
    : 'hover:bg-gray-100/60 dark:hover:bg-gray-850'

  const iconClassName = `size-4 shrink-0 ${textColor}`
  const iconTooltipInfo =
    isCustomEvent || isGoal
      ? isGoal
        ? GOAL_KIND_LABELS[step.goal_kind ?? 'plain']
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
        className={`group relative w-full text-left text-sm rounded-sm overflow-hidden focus:outline-none ${rowBg}`}
        onClick={() => onSelect(isSelected ? null : step)}
      >
        {barWidth !== null && (
          <div
            className={`absolute top-0 left-0 h-full rounded-sm transition-[width] ease-in-out ${barBg}`}
            data-testid="metric-bar"
            style={{ width: `${barWidth}%` }}
          />
        )}

        <div className="relative flex items-center justify-between gap-2 px-2 py-1.5">
          <span
            className={`flex items-center gap-2 min-w-0 ${textColor}`}
            title={step.label}
            data-testid="metric-label"
          >
            {iconElement}
            <span className="truncate">{step.label}</span>
          </span>

          {visitorsToShow !== null && (
            <span className={`shrink-0 font-medium ${textColor}`}>
              <VisitorsMetric visitors={visitorsToShow} />
            </span>
          )}
        </div>
      </button>
    </li>
  )
}

function VisitorsMetric({ visitors }: { visitors: number }): ReactNode {
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
  failed,
  pageTypingAllowed,
  onRetry
}: {
  active: boolean
  filter: string
  colIndex: number
  direction: ExplorationDirection
  rateLimited: boolean
  failed: boolean
  pageTypingAllowed: boolean
  onRetry: () => void
}): ReactNode {
  if (active && failed) {
    return (
      <span data-testid="exploration-column-error">
        Steps could not be loaded,{' '}
        <button
          onClick={onRetry}
          className="underline hover:text-gray-600 dark:hover:text-gray-300 focus:outline-none"
        >
          try again
        </button>
      </span>
    )
  }

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

  if (pageTypingAllowed) {
    return (
      <span className="flex flex-col items-center gap-2">
        <MagnifyingGlassIcon className="size-4.5" />
        Search, or type a page like /login to use it as a step
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

export function MaxDepthColumn({
  colIndex,
  header,
  message
}: {
  colIndex: number
  header: string
  message?: string
}): ReactNode {
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
          {message ??
            `You've reached the maximum journey depth of ${maxJourneySteps} steps.`}
        </span>
      </div>
    </div>
  )
}

export function ExplorationColumn({
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
  maxVisitors,
  filter,
  onFilterChange,
  onSelect,
  rateLimited,
  failed = false,
  pageTypingAllowed = false,
  showSuggestionCounts = true,
  onRetry
}: {
  colIndex: number
  direction: ExplorationDirection
  onDirectionChange: ((direction: ExplorationDirection) => void) | undefined
  header: string
  headerConversionRate: string | null
  active: boolean
  loading: boolean
  loadingInBackground: boolean
  results: JourneySuggestion[]
  selected: SelectedSuggestion | null
  maxVisitors: number
  filter: string
  onFilterChange: (filter: string) => void
  onSelect: (step: JourneyStep | null) => void
  rateLimited: boolean
  failed?: boolean
  // Lets the user type a page to use as a step, so the search box is always shown
  pageTypingAllowed?: boolean
  showSuggestionCounts?: boolean
  onRetry: () => void
}): ReactNode {
  const debouncedFilterChange = useDebounce((e: InputEvent) =>
    onFilterChange((e.target as HTMLInputElement).value)
  )

  // Track how many times the user has clicked "Show N more" for this column.
  // Reset whenever the underlying results array reference changes so a new
  // candidate list (filter change, journey change, etc.) starts collapsed.
  const [expandCount, setExpandCount] = useState(0)
  useEffect(() => {
    setExpandCount(0)
  }, [results])

  // If the selected step lives beyond INITIAL_VISIBLE_CANDIDATES in a frozen
  // column, make sure it is still visible by expanding the base window to
  // include it. The user picked it from a list they could see, so it should
  // remain visible after selection.
  const selectedIndex =
    selected && results.length > 0
      ? results.findIndex(({ step }) => journeyStepsEqual(step, selected.step))
      : -1
  const baseVisibleCount = Math.max(
    INITIAL_VISIBLE_CANDIDATES,
    selectedIndex >= 0 ? selectedIndex + 1 : 0
  )
  const visibleCount = Math.min(
    results.length,
    baseVisibleCount + expandCount * SHOW_MORE_INCREMENT
  )
  const remainingCount = Math.max(0, results.length - visibleCount)
  const showMoreCount = Math.min(SHOW_MORE_INCREMENT, remainingCount)

  // When a step is selected but there are no candidate results,
  // synthesise a single-item list from the funnel data so
  // the selected step is still rendered in the column.
  const listItems =
    selected && results.length === 0
      ? [{ step: selected.step, visitors: selected.visitors ?? 0 }]
      : results.slice(0, visibleCount)

  const stepMaxVisitors = maxVisitors ?? results[0]?.visitors ?? 1

  const showSearch =
    active && !selected && (results.length > 0 || !!filter || pageTypingAllowed)

  const onSelectHandler = loadingInBackground ? () => {} : onSelect

  return (
    <div
      data-testid={`exploration-column-${colIndex}`}
      data-exploration-column={colIndex}
      className="border border-gray-200 dark:border-gray-750 rounded-lg overflow-hidden"
    >
      <div className="h-[44px] py-1.5 pl-4 pr-1.5 flex items-center justify-between gap-x-2">
        {onDirectionChange ? (
          <InlineDropdown
            value={direction}
            options={DIRECTION_OPTIONS}
            onChange={onDirectionChange}
            testId="exploration-direction"
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
            failed={failed}
            pageTypingAllowed={pageTypingAllowed}
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
              key={`${step.goal_id ?? ''}:${step.name}:${step.label}:${step.includes_subpaths ? step.subpaths_count : 0}`}
              step={step}
              visitors={visitors}
              selected={selected}
              stepMaxVisitors={stepMaxVisitors}
              colIndex={colIndex}
              showCount={showSuggestionCounts}
              onSelect={onSelectHandler}
            />
          ))}
          {showMoreCount > 0 && (
            <li data-testid="exploration-row">
              <button
                onClick={() => setExpandCount((c) => c + 1)}
                className="group w-full text-sm rounded-sm hover:bg-gray-100/60 dark:hover:bg-gray-850 focus:outline-none"
              >
                <div
                  className={`flex items-center justify-between gap-2 px-2 py-1.5 ${
                    selected
                      ? 'text-gray-400 dark:text-gray-500 group-hover:text-gray-600 dark:group-hover:text-gray-400'
                      : 'text-gray-600 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-100'
                  }`}
                >
                  <span>{`Show ${showMoreCount} more`}</span>
                  <EllipsisHorizontalIcon className="size-4 shrink-0" />
                </div>
              </button>
            </li>
          )}
        </ul>
      )}
    </div>
  )
}
