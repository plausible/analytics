import React, {
  useState,
  useEffect,
  useLayoutEffect,
  useRef,
  useCallback
} from 'react'
import LazyLoader from '../components/lazy-loader'
import * as api from '../api'
import * as url from '../util/url'
import { Tooltip } from '../util/tooltip'
import { useDebounce } from '../custom-hooks'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import {
  numberShortFormatter,
  numberLongFormatter
} from '../util/number-formatter'
import { RefreshIcon, CursorIcon } from '../components/icons'
import { ChevronUpDownIcon, ChevronRightIcon } from '@heroicons/react/20/solid'
import { FlagIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline'
import { popover } from '../components/popover'

const DIRECTION = { FORWARD: 'forward', BACKWARD: 'backward' }

const DIRECTION_OPTIONS = [
  { value: DIRECTION.FORWARD, label: 'Starting point' },
  { value: DIRECTION.BACKWARD, label: 'End point' }
]

const PAGE_FILTER_KEYS = ['page', 'entry_page', 'exit_page']

const MAX_VISIBLE_CANDIDATES = 10
const MIN_GRID_COLUMNS = 3
const PRELOAD_MAX_STEPS = 2
const PRELOAD_MAX_CANDIDATES = MAX_VISIBLE_CANDIDATES

const EMPTY_JOURNEY_STATE = {
  steps: [],
  funnel: [],
  activeResults: [],
  activeFilter: '',
  frozen: {},
  provisional: {}
}

const EMPTY_SVG_DATA = {
  paths: [],
  width: 0,
  height: 0,
  clipY: 0,
  clipHeight: 0
}

// Two steps are identical when their identity fields match.
function stepsEqual(a, b) {
  return (
    a.name === b.name &&
    a.pathname === b.pathname &&
    a.includes_subpaths === b.includes_subpaths
  )
}

// Strip page-related filters from the dashboard state when a journey is
// active - the journey itself defines the page scope.
function dashboardStateForQuery(dashboardState, steps) {
  if (steps.length === 0) return dashboardState
  return {
    ...dashboardState,
    filters: dashboardState.filters.filter(
      ([_op, key]) => !PAGE_FILTER_KEYS.includes(key)
    )
  }
}

// Serialize steps into the wire format expected by the API.
function stepsToJourneyParam(steps) {
  return JSON.stringify(
    steps.map(({ name, pathname, includes_subpaths, subpaths_count }) => ({
      name,
      pathname,
      includes_subpaths,
      subpaths_count
    }))
  )
}

// Keep only entries with index < fromIndex, discarding everything at or after.
// Used to truncate frozen candidate snapshots when the journey is shortened.
function truncateFrozenAt(frozen, fromIndex) {
  const result = {}
  for (const key of Object.keys(frozen)) {
    if (Number(key) < fromIndex) result[key] = frozen[key]
  }
  return result
}

// Column header label based on index and direction.
function columnHeader(index, direction) {
  if (index === 0) {
    return direction === DIRECTION.BACKWARD ? 'End point' : 'Starting point'
  }
  const word = direction === DIRECTION.BACKWARD ? 'before' : 'after'
  return `${index} step${index === 1 ? '' : 's'} ${word}`
}

function fetchNextWithFunnel(
  site,
  dashboardState,
  steps,
  filter,
  direction,
  includeFunnel
) {
  return api.post(
    url.apiPath(site, '/exploration/next-with-funnel'),
    dashboardStateForQuery(dashboardState, steps),
    {
      journey: stepsToJourneyParam(steps),
      search_term: filter,
      direction,
      include_funnel: includeFunnel
    }
  )
}

function fetchInterestingFunnel(site, dashboardState) {
  return api.post(
    url.apiPath(site, '/exploration/interesting-funnel'),
    dashboardState,
    { max_steps: PRELOAD_MAX_STEPS, max_candidates: PRELOAD_MAX_CANDIDATES }
  )
}

// x-coordinate of a column element's left or right edge in the coordinate
// space of the scroll container, stable across horizontal scrolling.
function columnEdgeX(colEl, side, containerRect, scrollLeft) {
  const rect = colEl.getBoundingClientRect()
  const edgeX = side === 'right' ? rect.right : rect.left
  return edgeX - containerRect.left + scrollLeft
}

// Vertical midpoint of a step row relative to the top of the container.
function stepRowMidY(stepRowEl, containerRect) {
  const rect = stepRowEl.getBoundingClientRect()
  return (rect.top + rect.bottom) / 2 - containerRect.top
}

// SVG path for a stepped connector with rounded corners.
function steppedPath(x1, y1, x2, y2) {
  const mx = (x1 + x2) / 2
  const dy = y2 - y1

  if (Math.abs(dy) < 1) {
    return `M ${x1} ${y1} H ${x2}`
  }

  const r = Math.min(10, Math.abs(dy) / 2)

  if (dy > 0) {
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 1 ${mx} ${y1 + r} V ${y2 - r} A ${r} ${r} 0 0 0 ${mx + r} ${y2} H ${x2}`
  } else {
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 0 ${mx} ${y1 - r} V ${y2 + r} A ${r} ${r} 0 0 1 ${mx + r} ${y2} H ${x2}`
  }
}

// Clip rect that keeps connectors inside the list area,
// preventing them from bleeding into column headers.
function listClipRect(container, containerRect) {
  const firstList = container.querySelector('[data-exploration-list]')
  if (!firstList) return { y: 0, height: container.clientHeight }
  const rect = firstList.getBoundingClientRect()
  return { y: rect.top - containerRect.top, height: rect.height }
}

function computeConnectors(container, steps) {
  const containerRect = container.getBoundingClientRect()
  const paths = []

  for (let i = 0; i < steps.length - 1; i++) {
    // Query by explicit column index so DOM order never causes a mismatch.
    const colA = container.querySelector(`[data-exploration-column="${i}"]`)
    const colB = container.querySelector(`[data-exploration-column="${i + 1}"]`)
    const rowA = container.querySelector(`[data-exploration-step="${i}"]`)
    const rowB = container.querySelector(`[data-exploration-step="${i + 1}"]`)

    if (colA && colB && rowA && rowB) {
      const x1 = columnEdgeX(colA, 'right', containerRect, container.scrollLeft)
      const x2 = columnEdgeX(colB, 'left', containerRect, container.scrollLeft)
      const y1 = stepRowMidY(rowA, containerRect)
      const y2 = stepRowMidY(rowB, containerRect)
      paths.push(steppedPath(x1, y1, x2, y2))
    }
  }

  const clip = listClipRect(container, containerRect)

  return {
    paths,
    width: container.scrollWidth,
    height: container.clientHeight,
    clipY: clip.y,
    clipHeight: clip.height
  }
}

// layoutKey is bumped whenever the DOM may have changed in a way that is not
// reflected by a steps reference change, e.g. a dashboardState update. It
// is the caller's responsibility to increment it after such changes.
function PathConnectors({ steps, containerRef, layoutKey }) {
  const [svgData, setSvgData] = useState(EMPTY_SVG_DATA)

  const recalculate = useCallback(() => {
    const container = containerRef.current
    if (container) setSvgData(computeConnectors(container, steps))
  }, [steps, containerRef])

  useLayoutEffect(() => {
    const container = containerRef.current

    if (!container || steps.length < 2) {
      setSvgData(EMPTY_SVG_DATA)
      return
    }

    setSvgData(computeConnectors(container, steps))

    const observer = new ResizeObserver(recalculate)
    observer.observe(container)
    window.addEventListener('resize', recalculate)

    const lists = Array.from(
      container.querySelectorAll('[data-exploration-list]')
    )
    lists.forEach((list) => list.addEventListener('scroll', recalculate))

    return () => {
      observer.disconnect()
      window.removeEventListener('resize', recalculate)
      lists.forEach((list) => list.removeEventListener('scroll', recalculate))
    }
    // layoutKey is intentionally included: it forces this effect to re-run
    // and recalculate geometry after DOM updates that don't change steps.
  }, [steps, containerRef, recalculate, layoutKey])

  if (svgData.paths.length === 0) return null

  return (
    <svg
      className="absolute inset-0 pointer-events-none overflow-visible"
      height={svgData.height}
    >
      <defs>
        <clipPath id="exploration-list-clip">
          <rect
            x="0"
            y={svgData.clipY}
            width={svgData.width}
            height={svgData.clipHeight}
          />
        </clipPath>
      </defs>
      {svgData.paths.map((d, i) => (
        <path
          key={i}
          d={d}
          fill="none"
          clipPath="url(#exploration-list-clip)"
          className="stroke-indigo-500 dark:stroke-indigo-400"
          strokeWidth="1.5"
        />
      ))}
    </svg>
  )
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
  const isCustomEvent = step.name !== 'pageview'

  const visitorsToShow =
    isSelected && selectedVisitors !== null ? selectedVisitors : visitors
  const barWidth =
    isSelected && selectedConversionRate !== null
      ? selectedConversionRate
      : Math.round((visitors / stepMaxVisitors) * 100)

  const textColour = isDimmed
    ? 'text-gray-400 dark:text-gray-500'
    : 'text-gray-900 dark:text-gray-100'

  const subpathColour = isDimmed
    ? 'text-gray-400 dark:text-gray-500'
    : 'text-gray-500 dark:text-gray-400'

  return (
    <li>
      <button
        data-exploration-step={isSelected ? colIndex : undefined}
        className={`group w-full border text-left px-4 py-3 text-sm rounded-md focus:outline-none ${
          isSelected
            ? 'bg-indigo-50 dark:bg-gray-600/70 border-indigo-100 dark:border-transparent'
            : 'bg-white dark:bg-gray-750 border-gray-150 dark:border-gray-750'
        }`}
        onClick={() => onSelect(isSelected ? null : step)}
      >
        <div className="flex items-center justify-between gap-2 mb-1">
          <span
            className={`flex items-center gap-1.5 min-w-0 ${textColour}`}
            title={
              step.includes_subpaths
                ? `${step.label} > all (${step.subpaths_count})`
                : step.label
            }
          >
            {isCustomEvent && (
              <CursorIcon
                title="Custom event"
                className={`size-4 shrink-0 ${isDimmed ? 'text-gray-300 dark:text-gray-600' : 'text-gray-900 dark:text-gray-100'}`}
              />
            )}
            <span className="truncate">{step.label}</span>
            {step.includes_subpaths && (
              <>
                <ChevronRightIcon
                  className={`mt-0.5 size-3 shrink-0 ${subpathColour}`}
                />
                <span className={`shrink-0 ${subpathColour}`}>
                  all{' '}
                  <span className="text-[0.85rem]">
                    ({numberShortFormatter(step.subpaths_count)})
                  </span>
                </span>
              </>
            )}
          </span>

          <span
            className={`shrink-0 font-medium ${isDimmed ? 'text-gray-400 dark:text-gray-500' : 'text-gray-800 dark:text-gray-200'}`}
          >
            <Tooltip info={numberLongFormatter(visitorsToShow)}>
              {numberShortFormatter(visitorsToShow)}
            </Tooltip>
          </span>
        </div>

        <div
          className={`h-1 rounded-full overflow-hidden ${
            isSelected
              ? 'bg-indigo-200/70 dark:bg-gray-500/60'
              : isDimmed
                ? 'bg-gray-150 dark:bg-gray-700'
                : 'bg-gray-150 dark:bg-gray-600'
          }`}
        >
          <div
            className={`h-full rounded-full transition-[width] ease-in-out ${
              isSelected
                ? 'bg-indigo-500 dark:bg-indigo-400'
                : isDimmed
                  ? 'bg-indigo-200 dark:bg-indigo-400/30'
                  : 'bg-indigo-300 dark:bg-indigo-400/75 group-hover:bg-indigo-400 dark:group-hover:bg-indigo-400'
            }`}
            style={{ width: `${barWidth}%` }}
          />
        </div>
      </button>
    </li>
  )
}

function ColumnEmptyState({ active, filter, colIndex, direction }) {
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

function ExplorationColumn({
  colIndex,
  direction,
  onDirectionChange,
  header,
  headerConversionRate,
  active,
  loading,
  results,
  selected,
  selectedVisitors,
  selectedConversionRate,
  maxVisitors,
  filter,
  onFilterChange,
  onSelect
}) {
  const debouncedFilterChange = useDebounce((e) =>
    onFilterChange(e.target.value)
  )

  // When a step is selected but there are no candidate results, e.g. from a
  // preloaded journey, synthesise a single-item list from the funnel data so
  // the selected step is still rendered in the column.
  const listItems =
    selected && results.length === 0
      ? [{ step: selected, visitors: selectedVisitors ?? 0 }]
      : results.slice(0, MAX_VISIBLE_CANDIDATES)

  const stepMaxVisitors = maxVisitors ?? results[0]?.visitors

  const showSearch = active && !selected && (results.length > 0 || filter)

  return (
    <div
      data-exploration-column={colIndex}
      className="bg-gray-50 dark:bg-gray-850 rounded-lg overflow-hidden"
    >
      <div className="h-[42px] py-2 pl-4 pr-1.5 flex items-center justify-between gap-x-2">
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
            className="peer max-w-48 w-full text-xs dark:text-gray-100 block border-gray-300 dark:border-gray-700 rounded-md dark:bg-gray-700 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          />
        )}

        {headerConversionRate && (
          <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
            {headerConversionRate}
          </span>
        )}
      </div>

      {loading ? (
        <div className="h-110 flex items-center justify-center">
          <div className="mx-auto loading pt-4">
            <div></div>
          </div>
        </div>
      ) : listItems.length === 0 ? (
        <div className="h-110 flex items-center justify-center max-w-2/3 mx-auto text-center text-sm text-pretty text-gray-400 dark:text-gray-500">
          <ColumnEmptyState
            active={active}
            filter={filter}
            colIndex={colIndex}
            direction={direction}
          />
        </div>
      ) : (
        <ul
          data-exploration-list
          className="flex flex-col gap-y-2 px-2 pb-2 h-110 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
        >
          {listItems.map(({ step, visitors }) => (
            <CandidateCard
              key={`${step.name}:${step.label}:${step.includes_subpaths ? step.subpaths_count : 0}`}
              step={step}
              visitors={visitors}
              isSelected={!!selected && stepsEqual(step, selected)}
              isDimmed={!!selected && !stepsEqual(step, selected)}
              selectedVisitors={selectedVisitors}
              selectedConversionRate={selectedConversionRate}
              stepMaxVisitors={stepMaxVisitors}
              colIndex={colIndex}
              onSelect={onSelect}
            />
          ))}
        </ul>
      )}
    </div>
  )
}

// Compute provisional funnel entries for a newly selected step so the UI
// displays sensible values immediately before the API responds.
function provisionalEntry(step, columnIndex, sourceResults, existingFunnel) {
  const match = sourceResults.find(({ step: s }) => stepsEqual(s, step))
  if (!match) return {}

  const firstStepVisitors = existingFunnel[0]?.visitors ?? match.visitors
  const conversionRate = Math.round((match.visitors / firstStepVisitors) * 100)
  return {
    [columnIndex]: { visitors: match.visitors, conversion_rate: conversionRate }
  }
}

// useExplorationData manages all async data fetching, cancellation, and
// journey state.
function useExplorationData(site, dashboardState, inViewport) {
  const [state, setState] = useState(EMPTY_JOURNEY_STATE)
  const [activeLoading, setActiveLoading] = useState(false)
  // Incremented whenever the dashboardState or site changes so that
  // PathConnectors re-runs its layout effect and recalculates connector
  // geometry against the freshly rendered DOM. Steps alone do not change
  // on a context switch, so without this the SVG paths would be stale.
  const [layoutKey, setLayoutKey] = useState(0)

  // Track whether the initial preload has fired and whether the most recent
  // funnel data came from that preload, so we skip an immediately redundant
  // funnel refetch.
  const preloadFiredRef = useRef(false)
  const funnelFromPreloadRef = useRef(false)

  // Ref-copies of the previous dependency values so the main effect can detect
  // which dimension changed without adding them to the dep array.
  const prevStepsRef = useRef(state.steps)
  const prevDirectionRef = useRef(DIRECTION.FORWARD)
  const prevDashboardStateRef = useRef(dashboardState)

  // Incremented on every user-driven journey mutation. Stale async callbacks
  // capture the version at dispatch time and abort if it no longer matches.
  const journeyVersionRef = useRef(0)

  // Direction lives in a ref so that changing it resets state in one render
  // without causing a double-fetch from a direction state update racing with
  // a steps state update.
  const directionRef = useRef(DIRECTION.FORWARD)

  const selectStep = useCallback((columnIndex, step) => {
    ++journeyVersionRef.current

    setState((prev) => {
      if (step === null) {
        // Deselect: truncate journey at columnIndex.
        return {
          ...prev,
          steps: prev.steps.slice(0, columnIndex),
          activeResults: [],
          activeFilter: '',
          frozen: truncateFrozenAt(prev.frozen, columnIndex),
          provisional: {}
        }
      }

      // Select: determine source results for provisional values.
      const sourceResults =
        columnIndex === prev.steps.length
          ? prev.activeResults
          : (prev.frozen[columnIndex] ?? [])

      const newFrozen =
        columnIndex === prev.steps.length
          ? {
              ...truncateFrozenAt(prev.frozen, columnIndex),
              [columnIndex]: prev.activeResults
            }
          : truncateFrozenAt(prev.frozen, columnIndex + 1)

      return {
        ...prev,
        steps: [...prev.steps.slice(0, columnIndex), step],
        activeResults: [],
        activeFilter: '',
        frozen: newFrozen,
        provisional: provisionalEntry(
          step,
          columnIndex,
          sourceResults,
          prev.funnel
        )
      }
    })
  }, [])

  const reset = useCallback(() => {
    ++journeyVersionRef.current
    setState(EMPTY_JOURNEY_STATE)
  }, [])

  const setDirection = useCallback((newDirection) => {
    if (newDirection === directionRef.current) return
    directionRef.current = newDirection
    ++journeyVersionRef.current
    setState(EMPTY_JOURNEY_STATE)
  }, [])

  const setActiveFilter = useCallback((filter) => {
    setState((prev) => ({ ...prev, activeFilter: filter }))
  }, [])

  // Frozen candidate lists were fetched against a specific site and dashboard
  // filter context. When either changes the cached candidates become stale, so
  // drop them. We also bump layoutKey so PathConnectors recalculates geometry
  // after the DOM settles. Skip the initial run to avoid clobbering freshly
  // populated state on mount.
  const isFirstContextChangeRef = useRef(true)
  useEffect(() => {
    if (isFirstContextChangeRef.current) {
      isFirstContextChangeRef.current = false
      return
    }
    ++journeyVersionRef.current
    setState((prev) => ({ ...prev, frozen: {} }))
    setLayoutKey((k) => k + 1)
  }, [site, dashboardState])

  useEffect(() => {
    if (!inViewport) return

    const currentDirection = directionRef.current
    const steps = state.steps
    const activeFilter = state.activeFilter

    const journeyChanged =
      prevStepsRef.current !== steps ||
      prevDirectionRef.current !== currentDirection ||
      prevDashboardStateRef.current !== dashboardState

    prevStepsRef.current = steps
    prevDirectionRef.current = currentDirection
    prevDashboardStateRef.current = dashboardState

    // Capture the version at effect-dispatch time so stale responses are
    // discarded if the user mutates the journey before the response arrives.
    const capturedVersion = journeyVersionRef.current
    const isStale = () => journeyVersionRef.current !== capturedVersion

    setActiveLoading(true)

    // On first render fire the interesting-funnel preload. Once the preload
    // resolves it sets steps and funnel, which re-triggers this effect for
    // the active-column candidate fetch.
    if (!preloadFiredRef.current) {
      preloadFiredRef.current = true

      fetchInterestingFunnel(site, dashboardState)
        .then((response) => {
          if (isStale()) return
          if (response?.funnel?.length > 0) {
            funnelFromPreloadRef.current = true
            setState((prev) => ({
              ...prev,
              steps: response.funnel.map(({ step }) => step),
              funnel: response.funnel,
              frozen: response.candidates ?? {}
            }))
            // The preload populates steps, which re-triggers this effect for
            // the active-column candidate fetch, so leave loading=true.
          } else {
            // No interesting funnel found; fall back to plain candidates for column 0.
            fetchNextWithFunnel(
              site,
              dashboardState,
              [],
              '',
              currentDirection,
              false
            )
              .then((r) => {
                if (!isStale())
                  setState((prev) => ({
                    ...prev,
                    activeResults: r?.next ?? []
                  }))
              })
              .catch(() => {
                if (!isStale())
                  setState((prev) => ({ ...prev, activeResults: [] }))
              })
              .finally(() => {
                if (!isStale()) setActiveLoading(false)
              })
          }
        })
        .catch(() => {
          if (isStale()) return
          fetchNextWithFunnel(
            site,
            dashboardState,
            [],
            '',
            currentDirection,
            false
          )
            .then((r) => {
              if (!isStale())
                setState((prev) => ({ ...prev, activeResults: r?.next ?? [] }))
            })
            .catch(() => {
              if (!isStale())
                setState((prev) => ({ ...prev, activeResults: [] }))
            })
            .finally(() => {
              if (!isStale()) setActiveLoading(false)
            })
        })

      return
    }

    // On subsequent renders fetch next steps and, if the journey changed,
    // also refetch the funnel.

    const funnelAlreadyLoaded = funnelFromPreloadRef.current
    funnelFromPreloadRef.current = false

    const includeFunnel =
      journeyChanged && steps.length > 0 && !funnelAlreadyLoaded

    if (journeyChanged && steps.length === 0) {
      setState((prev) => ({ ...prev, funnel: [] }))
    }

    fetchNextWithFunnel(
      site,
      dashboardState,
      steps,
      activeFilter,
      currentDirection,
      includeFunnel
    )
      .then((response) => {
        if (isStale()) return
        setState((prev) => {
          const next = { ...prev, activeResults: response?.next ?? [] }
          if (includeFunnel) {
            const newFunnel = response?.funnel ?? []
            next.funnel = newFunnel
            next.provisional = {}
            // Sync subpaths_count on existing steps from the refreshed funnel
            // so that step identity stays consistent with what the API now
            // reports for the current period. Without this, a period change
            // leaves stale subpaths_count values in steps while frozen
            // candidates and new results carry fresh values, causing duplicate
            // entries and double-highlighted rows.
            if (newFunnel.length > 0 && prev.steps.length > 0) {
              const synced = prev.steps.map((s, idx) =>
                newFunnel[idx]
                  ? { ...s, subpaths_count: newFunnel[idx].step.subpaths_count }
                  : s
              )
              // Only replace the steps reference when something actually changed
              // to avoid re-triggering the main effect (steps is a dep array entry).
              const changed = synced.some(
                (s, idx) => s.subpaths_count !== prev.steps[idx].subpaths_count
              )
              if (changed) next.steps = synced
            }
          }
          return next
        })
      })
      .catch(() => {
        if (isStale()) return
        setState((prev) => ({
          ...prev,
          activeResults: [],
          ...(includeFunnel ? { funnel: [] } : {})
        }))
      })
      .finally(() => {
        if (!isStale()) setActiveLoading(false)
      })
  }, [site, dashboardState, state.steps, state.activeFilter, inViewport])
  // direction is intentionally excluded from the dep array. It lives in a ref
  // and resets state, which does appear above, so the state update itself
  // drives the re-run without double-firing.

  return {
    state,
    direction: directionRef.current,
    activeLoading,
    layoutKey,
    selectStep,
    reset,
    setDirection,
    setActiveFilter
  }
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

  const {
    state,
    direction,
    activeLoading,
    layoutKey,
    selectStep,
    reset,
    setDirection,
    setActiveFilter
  } = useExplorationData(site, dashboardState, inViewport)

  const { steps, funnel, activeResults, activeFilter, frozen, provisional } =
    state

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
    activeResults.length === 0

  const lastFunnelStep = funnel.length >= 2 ? funnel[funnel.length - 1] : null
  const overallConversionRate = lastFunnelStep?.conversion_rate ?? null
  const overallConversionVisitors = lastFunnelStep?.visitors ?? null

  return (
    <LazyLoader onVisible={() => setInViewport(true)}>
      <div className="flex-1 flex flex-col gap-4 pt-4">
        <div className="flex flex-wrap items-center gap-x-3">
          <h4 className="flex-1 text-base font-semibold dark:text-gray-100">
            {funnel.length >= 2
              ? `${funnel.length}-step user journey`
              : 'Explore user journeys'}
          </h4>

          {overallConversionRate != null && (
            <div className="order-last sm:order-none w-full sm:w-auto flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
              <span>
                <span className="font-medium sm:font-semibold text-gray-700 dark:text-gray-200">
                  Conversion: {parseFloat(overallConversionRate).toFixed(1)}%{' '}
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
              gridTemplateColumns: `repeat(${gridColumns}, minmax(18rem, 1fr))`
            }}
          >
            {Array.from({ length: numColumns }, (_, i) => {
              const isActive = i === activeColumnIndex
              const isReachable = steps.length >= i

              const colResults = isActive ? activeResults : (frozen[i] ?? [])
              const colLoading = isActive && (initialLoading || activeLoading)

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

              return (
                <ExplorationColumn
                  key={i}
                  colIndex={i}
                  direction={direction}
                  onDirectionChange={i === 0 ? setDirection : undefined}
                  header={columnHeader(i, direction)}
                  headerConversionRate={colHeaderConversionRate}
                  active={isReachable}
                  loading={colLoading}
                  results={colResults}
                  selected={steps[i] ?? null}
                  selectedVisitors={colSelectedVisitors}
                  selectedConversionRate={colSelectedConversionRate}
                  maxVisitors={funnel[0]?.visitors ?? null}
                  filter={isActive ? activeFilter : ''}
                  onFilterChange={isActive ? setActiveFilter : () => {}}
                  onSelect={(step) => selectStep(i, step)}
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
